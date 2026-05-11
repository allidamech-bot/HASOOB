{{flutter_js}}
{{flutter_build_config}}

if (typeof logDiagnostic === 'function') {
  logDiagnostic("flutter.js loaded");
}

const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
              (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

(function() {
  try {
    let swSettings = {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    };

    if (isIOS) {
      if (typeof logDiagnostic === 'function') logDiagnostic("iOS detected: preferring CanvasKit renderer");
      swSettings = null; // Disable service worker registration on iOS Safari
    }

    if (typeof logDiagnostic === 'function') {
        logDiagnostic("loader started");
    }

    _flutter.loader.load({
      serviceWorkerSettings: swSettings,
      onEntrypointLoaded: async function(engineInitializer) {
        if (typeof logDiagnostic === 'function') logDiagnostic("engine initializer received");

        if (!isIOS) {
          try {
            if (typeof logDiagnostic === 'function') logDiagnostic("initializeEngine(renderer=auto)");
            const appRunner = await engineInitializer.initializeEngine({ renderer: "auto" });
            if (typeof logDiagnostic === 'function') logDiagnostic("engine initialized (renderer=auto)");
            await appRunner.runApp();
            if (typeof logDiagnostic === 'function') logDiagnostic("runApp called");
            return;
          } catch (e) {
            if (typeof logDiagnostic === 'function') logDiagnostic("Engine init error (renderer=auto): " + e);
            console.error("Flutter initialization failed (renderer=auto):", e);
            showFatalError(e);
            return;
          }
        }

        const renderersToTry = ["canvaskit", "auto", "html"];
        let lastError = null;
        for (const renderer of renderersToTry) {
          try {
            if (typeof logDiagnostic === 'function') logDiagnostic("initializeEngine(renderer=" + renderer + ")");
            const appRunner = await engineInitializer.initializeEngine({ renderer });
            if (typeof logDiagnostic === 'function') logDiagnostic("engine initialized (renderer=" + renderer + ")");
            await appRunner.runApp();
            if (typeof logDiagnostic === 'function') logDiagnostic("runApp called");
            return;
          } catch (e) {
            lastError = e;
            if (typeof logDiagnostic === 'function') logDiagnostic("Engine init error (renderer=" + renderer + "): " + e);
            console.error("Flutter initialization failed (renderer=" + renderer + "):", e);
          }
        }

        showFatalError(lastError);
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
