import 'package:shelf/shelf.dart';

/// Adds `X-Content-Type-Options: nosniff` to every response, so a browser
/// never guesses that a plain-text error (which may contain request-shaped
/// text) is HTML or a script. The hijacked SSE stream bypasses middleware;
/// it only ever sends `text/event-stream`.
Middleware noSniff() =>
    (inner) => (request) async {
      final response = await inner(request);
      return response.change(headers: {'x-content-type-options': 'nosniff'});
    };
