{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
                  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);

    function isWebGL2Available() {
      try {
        const canvas = document.createElement('canvas');
        return !!(window.WebGL2RenderingContext && canvas.getContext('webgl2'));
      } catch (e) {
        return false;
      }
    }

    let rendererConfig = "auto";

    if (isIOS && isSafari) {
      console.log("Detecting iOS Safari - evaluating renderer options.");
      if (!isWebGL2Available()) {
        console.warn("WebGL2 not available on this iOS device. Falling back to HTML renderer.");
        rendererConfig = "html";
      } else {
        // We use "auto" to allow Flutter to choose the best available (Skwasm, CanvasKit, or HTML).
        // Forcing "html" is often detrimental to complex UIs and charts.
        rendererConfig = "auto";
      }
    }

    try {
      const appRunner = await engineInitializer.initializeEngine({
        renderer: rendererConfig,
      });
      await appRunner.runApp();
    } catch (e) {
      console.error("Flutter initialization failed:", e);
      // Fallback mechanism for iOS Safari if CanvasKit/Skwasm fails to initialize
      if (rendererConfig !== "html") {
        console.warn("Attempting fallback to HTML renderer...");
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

    function showFatalError(err) {
      document.body.innerHTML = `
        <div style="background:#0B1020; color:white; height:100vh; display:flex; flex-direction:column; align-items:center; justify-content:center; font-family:sans-serif; padding:20px; text-align:center;">
          <h2 style="color:#ff4d4d">Initialization Failed</h2>
          <p>The app could not start on this browser version.</p>
          <p style="font-size:0.8em; color:#888; max-width:400px; margin:20px 0;">${err.message || err}</p>
          <button onclick="window.location.reload()" style="margin-top:20px; padding:12px 24px; background:#2F80ED; color:white; border:none; border-radius:8px; cursor:pointer;">Retry</button>
        </div>
      `;
    }
  }
});
