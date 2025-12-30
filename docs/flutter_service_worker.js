'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "d03dc3fb86a9fbe034fd636dcc1595fc",
"version.json": "4b44e334d036e60d27f08fd44479873d",
"index.html": "181bf1c2fc0f2aeea140894350dc2120",
"/": "181bf1c2fc0f2aeea140894350dc2120",
"main.dart.js": "992246b330ced9eb1ca0b3e46e23516b",
"sqlite3.wasm": "fa7637a49a0e434f2a98f9981856d118",
"webapp/flutter_bootstrap.js": "28910b1d8890e1a15e066b23215747a9",
"webapp/version.json": "18b256576090b77eebbe0db461b9558a",
"webapp/index.html": "181bf1c2fc0f2aeea140894350dc2120",
"webapp/main.dart.js": "311cc5426f64d11008a1b6428a67ff2c",
"webapp/sqlite3.wasm": "fa7637a49a0e434f2a98f9981856d118",
"webapp/flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"webapp/favicon.png": "c39db9989f8765730ae1248acb479d8d",
"webapp/sqflite_sw.js": "f4ac56fdbc3d69e942ffa2f28ed6ee51",
"webapp/icons/Icon-192.png": "d2aff28192b0963e5cc8aa533c66f672",
"webapp/icons/Icon-maskable-192.png": "d2aff28192b0963e5cc8aa533c66f672",
"webapp/icons/Icon-maskable-512.png": "304cd0c318fee3d03b18502d4c47e021",
"webapp/icons/Icon-512.png": "304cd0c318fee3d03b18502d4c47e021",
"webapp/manifest.json": "6520cc3397af1956f121536ed3381c46",
"webapp/assets/NOTICES": "fe908dd5762bbdc612465e09e6bdda58",
"webapp/assets/FontManifest.json": "448b0b015df0e4830cd7dd630ecd8be9",
"webapp/assets/AssetManifest.bin.json": "4ec99e9f5bc4447f517e906a3b5f8234",
"webapp/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"webapp/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"webapp/assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"webapp/assets/AssetManifest.bin": "53be51f006915938faa5924efadf6637",
"webapp/assets/fonts/MaterialIcons-Regular.otf": "7f7a19ba548cf62923e31b0203a6d752",
"webapp/assets/assets/icons/instal-app-logo.png": "b5921b8c6d0d76a2e7bd11acef1402c8",
"webapp/assets/assets/icons/instal-app-logo-rounded.png": "cef23094d52da90971aa1ef282fd78c4",
"webapp/assets/assets/fonts/Inter-Medium.ttf": "19c60c058e0be8f5e35bb24a0860ceac",
"webapp/assets/assets/fonts/Inter-Bold.ttf": "b3e2eeb0f23ab20e0e682c772c61bc26",
"webapp/assets/assets/fonts/Inter-Regular.ttf": "9776097c6ab2809996578cab11fa150a",
"webapp/assets/assets/fonts/Inter-SemiBold.ttf": "0ced422738bcdd42dc764d10f2cbb94c",
"webapp/canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"webapp/canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"webapp/canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"webapp/canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"webapp/canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"webapp/canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"webapp/canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"webapp/canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"webapp/canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"webapp/canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"webapp/canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"webapp/canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "c39db9989f8765730ae1248acb479d8d",
"sqflite_sw.js": "f4ac56fdbc3d69e942ffa2f28ed6ee51",
"icons/Icon-192.png": "d2aff28192b0963e5cc8aa533c66f672",
"icons/Icon-maskable-192.png": "d2aff28192b0963e5cc8aa533c66f672",
"icons/Icon-maskable-512.png": "304cd0c318fee3d03b18502d4c47e021",
"icons/Icon-512.png": "304cd0c318fee3d03b18502d4c47e021",
"manifest.json": "6520cc3397af1956f121536ed3381c46",
"assets/NOTICES": "fe908dd5762bbdc612465e09e6bdda58",
"assets/FontManifest.json": "448b0b015df0e4830cd7dd630ecd8be9",
"assets/AssetManifest.bin.json": "4ec99e9f5bc4447f517e906a3b5f8234",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "53be51f006915938faa5924efadf6637",
"assets/fonts/MaterialIcons-Regular.otf": "7f7a19ba548cf62923e31b0203a6d752",
"assets/assets/icons/instal-app-logo.png": "b5921b8c6d0d76a2e7bd11acef1402c8",
"assets/assets/icons/instal-app-logo-rounded.png": "cef23094d52da90971aa1ef282fd78c4",
"assets/assets/fonts/Inter-Medium.ttf": "19c60c058e0be8f5e35bb24a0860ceac",
"assets/assets/fonts/Inter-Bold.ttf": "b3e2eeb0f23ab20e0e682c772c61bc26",
"assets/assets/fonts/Inter-Regular.ttf": "9776097c6ab2809996578cab11fa150a",
"assets/assets/fonts/Inter-SemiBold.ttf": "0ced422738bcdd42dc764d10f2cbb94c",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
