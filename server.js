var express = require('express');
var exphbs = require('express-handlebars');
var app = express();
var os = require("os");
var dns = require("dns");
var http = require("http");
var morgan = require('morgan');

app.engine('handlebars', exphbs({ defaultLayout: 'main' }));
app.set('view engine', 'handlebars');
app.use(express.static('static'));
app.use(morgan('combined'));

// Configuration
var port = process.env.PORT || 8080;
var message = process.env.MESSAGE || "Hello world!";
var currentEgressIP = ""
var currentIngressIP = ""

app.get('/', function(req, res) {
    dns.lookup(req.headers.host.slice(0, req.headers.host.indexOf(":")), (err, result) => {
        console.log(currentIngressIP);
        currentIngressIP = result;
    });
    http.get({ host: "icanhazip.com", port: 80, path: '/' }, function(res) {
        var body = '';
        res.on('data', function(chunk) {
            body += chunk;
        });
        res.on('end', function() {
            console.log(body);
            currentEgressIP = body;
        });
    });
    res.render('home', {
        message: message,
        platform: os.type(),
        release: os.release(),
        hostName: os.hostname(),
        ingressIP: currentIngressIP,
        egressIP: currentEgressIP
    });
});

// Set up listener
app.listen(port, function() {
    console.log("Listening on: http://%s:%s", os.hostname(), port);
});