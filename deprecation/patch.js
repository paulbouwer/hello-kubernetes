// Adds the deprecation warning to an old hello-kubernetes image. It runs once,
// at build time, inside the old image, with that image's own Node (6.10 to
// 16.10), so it uses only syntax and modules that Node 6 has.
//
// It changes two things and nothing else:
//   - the page: the banner goes straight after <body ...>, in the Handlebars
//     layout (1.4 to 1.10.1), or in the HTML string in server.js (1.0 to 1.3)
//   - package.json: a prestart script prints the notice when npm start runs
// Any surprise, such as a missing <body>, fails the build.
'use strict';
var fs = require('fs');
var path = require('path');

var app = '/usr/src/app';
var here = path.join(app, '.deprecation');
var tag = process.env.DEPRECATED_TAG;
if (!tag) fail('DEPRECATED_TAG is not set');

function fail(message) {
  console.error('patch.js: ' + message);
  process.exit(1);
}

// The banner, for this tag, on one line with no single quotes, so it can sit
// inside the single-quoted HTML string in the 1.0 to 1.3 server.js.
var banner = fs.readFileSync(path.join(here, 'banner.html'), 'utf8').replace(/\{\{tag\}\}/g, tag).replace(/\s*\n\s*/g, ' ').trim();
if (banner.indexOf("'") !== -1) fail('banner.html must not contain a single quote');

function insertAfterBody(file) {
  var text = fs.readFileSync(file, 'utf8');
  var match = text.match(/<body[^>]*>/);
  if (!match) fail('no <body> in ' + file);
  var at = match.index + match[0].length;
  fs.writeFileSync(file, text.slice(0, at) + banner + text.slice(at));
  console.log('patch.js: added the banner to ' + path.relative(app, file));
}

var layout = path.join(app, 'views', 'layouts', 'main.handlebars');
if (fs.existsSync(layout)) insertAfterBody(layout);
else insertAfterBody(path.join(app, 'server.js'));

// The notice, printed by npm before it starts the app.
var pkgFile = path.join(app, 'package.json');
var pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));
if (!pkg.scripts || pkg.scripts.start !== 'node server.js') fail('unexpected start script in package.json');
if (pkg.scripts.prestart) fail('package.json already has a prestart script');
pkg.scripts.prestart = 'node .deprecation/notice.js';
fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2) + '\n');
fs.writeFileSync(path.join(here, 'notice.js'), fs.readFileSync(path.join(here, 'notice.js.in'), 'utf8').replace(/\{\{tag\}\}/g, tag));
console.log('patch.js: added the prestart notice to package.json');
