import 'dart:convert';

import 'package:dart_pact_consumer/dart_pact_consumer.dart';
import 'package:dart_pact_consumer/src/ffi/rust_mock_server.dart';
import 'package:dart_pact_consumer/src/pact_host_client.dart';

import 'pact_exceptions.dart';

/// Holder for pacts in their builder form.
///
/// Can merge several builders into a single [Pact] with all the combined
/// interactions
class PactRepository {
  final Map<String, Pact> _pacts = {};
  final bool requireTests;

  PactRepository({this.requireTests = true});

  /// Adds all the request-response pairs as interactions in a [Pact] structure.
  void add(PactBuilder builder) {
    builder.validate(requireTests: requireTests);
    final contract = _pacts.putIfAbsent(
        _key(builder.consumer, builder.provider), () => _createHeader(builder));
    _mergeInteractions(builder, contract);
  }

  /// Publishes all pacts onto a host with tagging a specific version
  Future<void> publish(PactHost host, String version) {
    if (RequestTester.hasErrors) {
      throw PactException("Can't publish when there are tests with errors");
    }
    final futures = _pacts.values.map((e) => host.publishContract(e, version));
    return Future.wait(futures);
  }

  /// Gets a pact file in JSON format
  String? getPactFile(String consumer, String provider) {
    return _pacts[_key(consumer, provider)]?.let((value) {
      return jsonEncode(value);
    });
  }

  static String _key(String consumer, String provider) => '$consumer|$provider';

  static Pact _createHeader(PactBuilder builder) {
    return Pact(
      provider: Provider(name: builder.provider),
      consumer: Consumer(name: builder.consumer),
    );
  }

  static void _mergeInteractions(PactBuilder builder, Pact contract) {
    final interactions = builder.stateBuilders.expand(
        (st) => st.requests.map((req) => _toInteraction(req, st.state)));

    if (interactions.isNotEmpty && contract.interactions == null) {
      contract.interactions = interactions.toList();
    } else if (interactions.isNotEmpty && contract.interactions != null) {
      contract.interactions!.addAll(interactions);
    }
  }

  static Interaction _toInteraction(
      RequestBuilder requestBuilder, String? state) {
    return Interaction(
      description: requestBuilder.description,
      // RESEARCH: Where are the params and multiple states gonna come from?
      providerStates: state == null ? [] : [ProviderState(name: state)],
      request: (_toRequest(requestBuilder)),
      response: (_toResponse(requestBuilder.response)),
    );
  }

  static Request _toRequest(RequestBuilder requestBuilder) {
    final query = Uri(queryParameters: requestBuilder.query).query;
    final decodedQuery = Uri.decodeComponent(query);
    return Request(
      method: _toMethod(requestBuilder.method),
      path: requestBuilder.path,
      query: decodedQuery,
      body: requestBuilder.body,
      headers: requestBuilder.headers,
    );
  }

  static Response _toResponse(ResponseBuilder response) {
    return Response(
      headers: response.headers,
      status: response.status.code,
      body: response.body,
    );
  }

  static String _toMethod(Method method) {
    const prefix = 'Method.';
    return method.toString().substring(prefix.length);
  }
}

typedef RequestTestFunction = Future<dynamic> Function(MockServer server);

class RequestTester {
  final PactBuilder _pactBuilder;
  final StateBuilder _stateBuilder;

  // todo shouldn't be static
  static bool hasErrors = false;

  RequestTester._(this._pactBuilder, this._stateBuilder);

  Future<void> test(
      MockServerFactory factory, RequestTestFunction testFunction) async {
    final pactBuilder = PactBuilder(
        consumer: _pactBuilder.consumer, provider: _pactBuilder.provider)
      ..stateBuilders.add(_stateBuilder);
    final pact = PactRepository._createHeader(pactBuilder);
    PactRepository._mergeInteractions(pactBuilder, pact);
    final server = factory.createMockServer(pact.interactions![0]);
    try {
      await testFunction(server);
      _stateBuilder._tested = true;
      if (!server.hasMatched()) {
        hasErrors = true;
        final mismatchJson = server.getMismatchJson();
        throw PactMatchingException(mismatchJson);
      }
    } finally {
      factory.closeServer(server);
    }
  }
}

/// DSL for building pact contracts.
///
/// Builds an interaction for each state-request-response tuple.
///
/// This DSL doesn't match with the formal specification by design.
/// For instance, the state is mandatory and only after that we can define
/// the requests.
/// These changes makes reasoning about pacts easier.
///
/// Not all features are available at first, but can be added as needed:
/// . Request matchers
/// . Generators
/// . Encoders
class PactBuilder {
  String consumer = '';
  String provider = '';
  final List<StateBuilder> _states = [];

  List<StateBuilder> get stateBuilders => _states;

  PactBuilder({
    required this.consumer,
    required this.provider,
  });

  // builder functions allow to change internals in the future
  RequestTester addState(void Function(StateBuilder stateBuilder) func) {
    final builder = StateBuilder._();
    func(builder);
    _states.add(builder);
    return RequestTester._(this, builder);
  }

  void validate({bool requireTests = true}) {
    stateBuilders.forEach((element) => element._validate(requireTests));
  }
}

enum Method { GET, POST, DELETE, PUT }

class StateBuilder {
  bool _tested = false;
  String? state;
  List<RequestBuilder> requests = [];

  StateBuilder._();

  void _validate(bool requireTests) {
    if (requireTests && !_tested) {
      throw PactException('State "$state" not tested');
    }
    requests.forEach((element) => element._validate());
    requests.forEach((element) => element._validate());
  }

  void addRequest(void Function(RequestBuilder reqBuilder) func) {
    final builder = RequestBuilder._();
    func(builder);
    requests.add(builder);
  }
}

class RequestBuilder {
  String _path = '/';

  String get path => _path;

  set path(String path) {
    if (path.startsWith('/')) {
      _path = path;
    } else {
      _path = '/$path';
    }
  }

  String description = '';
  Method method = Method.GET;
  ResponseBuilder? _response;
  Map<String, String>? query;
  Map<String, String>? headers;
  Body? body;

  ResponseBuilder get response {
    assert(_response != null);
    return _response!;
  }

  RequestBuilder._();

  void setResponse(void Function(ResponseBuilder respBuilder) func) {
    final builder = ResponseBuilder._();
    func(builder);
    _response = builder;
  }

  void _validate() {
    assert(_response != null);
  }
}

class ResponseBuilder {
  Map<String, String>? headers;
  Status status = Status(200);
  Body? body;

  ResponseBuilder._();
}
