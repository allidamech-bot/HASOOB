{{flutter_js}}
{{flutter_build_config}}

if (typeof logDiagnostic === 'function') {
  logDiagnostic("flutter.js loaded");
}

// Exactly once at top-level
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
              (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);

if (isIOS && isSafari) {
    window.flutterWebRenderer = "html";
}

(function() {
  try {
    let swSettings = {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    };

    if (isIOS && isSafari) {
      if (typeof logDiagnostic === 'function') logDiagnostic("iOS Safari detected: strictly forcing HTML mode");
      swSettings = null; // Disable service worker registration on iOS Safari
    }

    if (typeof logDiagnostic === 'function') {
        logDiagnostic("loader started");
        if (typeof inspectDOM === 'function') inspectDOM();
    }

    _flutter.loader.load({
      serviceWorkerSettings: swSettings,
      onEntrypointLoaded: async function(engineInitializer) {
        if (typeof logDiagnostic === 'function') logDiagnostic("engine initializer received");

        let config = {
          renderer: (isIOS && isSafari) ? "html" : "auto",
        };

        try {
          const appRunner = await engineInitializer.initializeEngine(config);

          if (typeof logDiagnostic === 'function') logDiagnostic("engine initialized (renderer=" + config.renderer + ")");
          if (typeof inspectDOM === 'function') inspectDOM();

          await appRunner.runApp();

          if (typeof logDiagnostic === 'function') {
              logDiagnostic("runApp called");
              setTimeout(() => {
                  const fv = document.querySelector('flutter-view');
                  if (fv) {
                      fv.style.setProperty('display', 'block', 'important');
                      fv.style.setProperty('width', '100vw', 'important');
                      fv.style.setProperty('height', '100vh', 'important');
                      fv.style.setProperty('position', 'fixed', 'important');
                      fv.style.setProperty('inset', '0', 'important');
                      fv.style.setProperty('z-index', '0', 'important');
                      logDiagnostic("Applied post-runApp style patch");
                  }

                  // Patch flt elements
                  const fltTags = ['flt-glass-pane', 'flt-scene-host', 'flt-platform-view'];
                  fltTags.forEach(tag => {
                      const el = document.querySelector(tag);
                      if (el) {
                          el.style.setProperty('display', 'block', 'important');
                          el.style.setProperty('width', '100%', 'important');
                          el.style.setProperty('height', '100%', 'important');
                          el.style.setProperty('visibility', 'visible', 'important');
                          el.style.setProperty('opacity', '1', 'important');
                      }
                  });

                  if (typeof inspectDOM === 'function') inspectDOM();
              }, 500);

              setTimeout(() => {
                  if (typeof inspectDOM === 'function') inspectDOM();
              }, 2000);
          }
        } catch (e) {
          if (typeof logDiagnostic === 'function') logDiagnostic("Engine init error: " + e);
          console.error("Flutter initialization failed:", e);

          if (config.renderer !== "html") {
            if (typeof logDiagnostic === 'function') logDiagnostic("Attempting fallback to HTML...");
            try {
              const appRunner = await engineInitializer.initializeEngine({
                renderer: "html",
              });
              await appRunner.runApp();
            } catch (retryError) {
              showFatalError(retryError);
            }
          } else {
            showFatalError(e);
          }
        }
      }
    });
  } catch (err) {
    if (typeof logDiagnostic === 'function') logDiagnostic("Bootstrap error: " + err);
    console.error("Bootstrap error:", err);
    showFatalError(err);
  }

  function showFatalError(err) {
    if (typeof logDiagnostic === 'function') logDiagnostic("FATAL: " + err);

    const errorDiv = document.createElement('div');
    errorDiv.style.cssText = "position:fixed; top:0; left:0; width:100%; height:100%; background:#0B1020; color:white; z-index:20000; display:flex; flex-direction:column; align-items:center; justify-content:center; font-family:sans-serif; padding:20px; text-align:center;";
    errorDiv.innerHTML = `
        <h2 style="color:#ff4d4d">Initialization Failed</h2>
        <p>The app could not start on this browser version.</p>
        <pre style="font-size:0.8em; color:#888; max-width:400px; margin:20px 0; white-space: pre-wrap;">${err.stack || err.message || err}</pre>
        <button onclick="window.location.reload()" style="margin-top:20px; padding:12px 24px; background:#2F80ED; color:white; border:none; border-radius:8px; cursor:pointer;">Retry</button>
    `;
    document.body.appendChild(errorDiv);
  }
})();
