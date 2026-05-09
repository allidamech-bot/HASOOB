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

    // Default to auto renderer
    let rendererConfig = "auto";

    if (isIOS && isSafari) {
      console.log("Detecting mobile Safari - switching to HTML renderer for compatibility.");
      rendererConfig = "html";
    }

    const appRunner = await engineInitializer.initializeEngine({
      renderer: rendererConfig,
    });
    await appRunner.runApp();
  }
});
