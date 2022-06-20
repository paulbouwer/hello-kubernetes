const express = require('express');
const { engine } = require('express-handlebars');
const os = require("os");
const fs = require('fs');

const pino = require('pino');
const expressPino = require('express-pino-logger');
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const expressLogger = expressPino({ logger });

const app = express();

// Begin of Prometheus metrics
const promClient = require('prom-client');;
const collectDefaultMetrics = promClient.collectDefaultMetrics;
const Registry = promClient.Registry;
const register = new Registry();
collectDefaultMetrics({ register });

register.setDefaultLabels({
  app: 'hello-kubernetes'
});

const httpRequestTimer = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'path', 'code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10] // 0.1 to 10 seconds
});

register.registerMetric(httpRequestTimer);

app.get('/metrics', async (req, res) => {
  // Return all metrics the Prometheus exposition format
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
// End of Prometheus metrics


// Handler for health checks (without logs)
app.get('/health', (req, res) => {
  const data = {
    uptime: process.uptime(),
    message: 'Ok',
    date: new Date()
  }
  res.status(200).send(data);
});

app.use(expressLogger);
app.engine('hbs', engine({ extname: '.hbs', defaultLayout: "main" }));
app.set('view engine', 'hbs');

// Configuration

var port = process.env.PORT || 8080;
var message = process.env.MESSAGE || 'Hello Kubernetes!';
var renderPathPrefix = (
  process.env.RENDER_PATH_PREFIX ?
    '/' + process.env.RENDER_PATH_PREFIX.replace(/^[\\/]+/, '').replace(/[\\/]+$/, '') :
    ''
);
var handlerPathPrefix = (
  process.env.HANDLER_PATH_PREFIX ?
    '/' + process.env.HANDLER_PATH_PREFIX.replace(/^[\\/]+/, '').replace(/[\\/]+$/, '') :
    ''
);

var namespace = process.env.KUBERNETES_NAMESPACE || '-';
var podName = process.env.KUBERNETES_POD_NAME || os.hostname();
var podIP = process.env.KUBERNETES_POD_IP || '-';
var nodeName = process.env.KUBERNETES_NODE_NAME || '-';
var nodeOS = os.type() + ' ' + os.release();
var applicationVersion = JSON.parse(fs.readFileSync('package.json', 'utf8')).version;
var containerImage = process.env.CONTAINER_IMAGE || 'eduardobaitello/hello-kubernetes:' + applicationVersion
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
logger.debug('KUBERNETES_POD_IP=' + process.env.KUBERNETES_POD_IP);
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

// GET Handler
app.get(handlerPathPrefix + '/*', function (req, res) {
  // Start the timer
  const end = httpRequestTimer.startTimer();
  res.render('home', {
    message: message,
    namespace: namespace,
    pod: podName,
    podIP: podIP,
    node: nodeName + ' (' + nodeOS + ')',
    reqProtocol: req.protocol,
    reqHostname: req.hostname,
    reqPath: req.path,
    reqMethod: req.method,
    container: containerImage + ' (' + containerImageArch + ')',
    renderPathPrefix: renderPathPrefix
  });
  // End timer and add labels
  end({ path: req.path, code: res.statusCode, method: req.method });
});

// POST Handler /random
// Random sleep time, random exit code (200 or 504). Useful for metrics samples
app.post(handlerPathPrefix + '/random', async (req, res) => {
  // Start the timer
  const end = httpRequestTimer.startTimer();

  // Random response time, until 6 seconds
  let rand = Math.round(Math.random() * 6000);
  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  await sleep(rand);

  const data = {
    message: message,
    namespace: namespace,
    pod: podName,
    podIP: podIP,
    node: nodeName + ' (' + nodeOS + ')',
    reqProtocol: req.protocol,
    reqHostname: req.hostname,
    reqPath: req.path,
    reqMethod: req.method,
    container: containerImage + ' (' + containerImageArch + ')',
  }

  // Return 504 when response > 5s
  if (rand > 5000) {
    var responseStatus = 504
  } else {
    var responseStatus = 200
  }
  res.status(responseStatus).send(data);
  // End timer and add labels
  end({ path: req.path, code: res.statusCode, method: req.method });
});

// POST Handler
app.post(handlerPathPrefix + '/*', function (req, res) {
  // Start the timer
  const end = httpRequestTimer.startTimer();
  const data = {
    message: message,
    namespace: namespace,
    pod: podName,
    podIP: podIP,
    node: nodeName + ' (' + nodeOS + ')',
    reqProtocol: req.protocol,
    reqHostname: req.hostname,
    reqPath: req.path,
    reqMethod: req.method,
    container: containerImage + ' (' + containerImageArch + ')',
  }
  res.status(200).send(data);
  // End timer and add labels
  end({ path: req.path, code: res.statusCode, method: req.method });
});

// Server

logger.debug();
logger.debug('Server');
logger.debug('-----------------------------------------------------');

app.listen(port, function () {
  logger.info("Listening on: http://%s:%s", podName, port);
});
