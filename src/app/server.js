const express = require('express');
const { engine } = require('express-handlebars');
const os = require("os");
const fs = require('fs');

const pino = require('pino');
const pinoHttp = require('pino-http');
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const expressLogger = pinoHttp({ logger });

const app = express();
app.use(expressLogger);
app.engine('handlebars', engine({defaultLayout: 'main'}));
app.set('view engine', 'handlebars');

// Configuration

var port = process.env.PORT || 8080;
var message = process.env.MESSAGE || 'Hello world!';
// A path prefix such as "app" or "/app/" becomes "/app". An empty prefix, or
// one that is only slashes, becomes "".
function normalisePrefix(value) {
  var path = (value || '').replace(/^[\\/]+/, '').replace(/[\\/]+$/, '');
  return path ? '/' + path : '';
}

var renderPathPrefix = normalisePrefix(process.env.RENDER_PATH_PREFIX);
var handlerPathPrefix = normalisePrefix(process.env.HANDLER_PATH_PREFIX);

// Asset URLs are absolute under a render prefix, and relative without one, so
// that the page also works behind a proxy that serves it under a path and
// strips that path (#38).
var assetPathPrefix = renderPathPrefix ? renderPathPrefix + '/' : '';

var namespace = process.env.KUBERNETES_NAMESPACE || '-';
var podName = process.env.KUBERNETES_POD_NAME || os.hostname();
var nodeName = process.env.KUBERNETES_NODE_NAME || '-';
var nodeOS = os.type() + ' ' + os.release();
var applicationVersion = JSON.parse(fs.readFileSync('package.json', 'utf8')).version;
var containerImage = process.env.CONTAINER_IMAGE || 'paulbouwer/hello-kubernetes:' + applicationVersion
var containerImageArch = JSON.parse(fs.readFileSync('info.json', 'utf8')).containerImageArch;

logger.debug();
logger.debug('Configuration');
logger.debug('-----------------------------------------------------');
logger.debug('PORT=' + process.env.PORT);
logger.debug('MESSAGE=' + process.env.MESSAGE);
logger.debug('RENDER_PATH_PREFIX=' + process.env.RENDER_PATH_PREFIX);
logger.debug('HANDLER_PATH_PREFIX=' + process.env.HANDLER_PATH_PREFIX);
logger.debug('KUBERNETES_NAMESPACE=' + process.env.KUBERNETES_NAMESPACE);
logger.debug('KUBERNETES_POD_NAME=' + process.env.KUBERNETES_POD_NAME);
logger.debug('KUBERNETES_NODE_NAME=' + process.env.KUBERNETES_NODE_NAME);
logger.debug('CONTAINER_IMAGE=' + process.env.CONTAINER_IMAGE);

// Handlers

logger.debug();
logger.debug('Handlers');
logger.debug('-----------------------------------------------------');

logger.debug('Handler: static assets');
logger.debug('Serving from base path "' + handlerPathPrefix + '"');
app.use(handlerPathPrefix, express.static('static'))

logger.debug('Handler: /');
logger.debug('Serving from base path "' + handlerPathPrefix + '"');
app.get(handlerPathPrefix + '/', function (req, res) {
    res.render('home', {
      message: message,
      namespace: namespace,
      pod: podName,
      node: nodeName + ' (' + nodeOS + ')',
      container: containerImage + ' (' + containerImageArch + ')',
      assetPathPrefix: assetPathPrefix
    });
});

// Server

logger.debug();
logger.debug('Server');
logger.debug('-----------------------------------------------------');

const server = app.listen(port, function (err) {
  if (err) {
    logger.error(err, 'Failed to listen on port %s', port);
    process.exit(1);
  }
  logger.info("Listening on: http://%s:%s", podName, port);
});

// Shutdown

// Stop accepting connections, close idle keep-alive connections, and exit
// when in-flight requests finish. Exit anyway after 5 seconds.
function shutdown(signal) {
  logger.info('Received %s, shutting down', signal);
  server.close(function () {
    logger.info('Server closed');
    process.exit(0);
  });
  server.closeIdleConnections();
  setTimeout(function () {
    logger.warn('Requests still open after 5 seconds, exiting');
    process.exit(1);
  }, 5000).unref();
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);