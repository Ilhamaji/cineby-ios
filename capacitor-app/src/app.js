document.addEventListener("DOMContentLoaded", function () {
  const rotateBtn = document.getElementById("rotateBtn");
  const fullBtn = document.getElementById("fullBtn");
  const openBtn = document.getElementById("openBtn");

  rotateBtn.addEventListener("click", async () => {
    // Try Screen Orientation API first
    const so = (screen.orientation || screen).lock;
    try {
      if (
        screen.orientation &&
        screen.orientation.type &&
        screen.orientation.type.startsWith("portrait")
      ) {
        await screen.orientation.lock("landscape");
      } else {
        await screen.orientation.lock("portrait");
      }
    } catch (e) {
      // Fallback: try to request fullscreen (some devices expand video into landscape)
      alert(
        "Native orientation lock not available in this environment. On iOS native app, install the screen-orientation plugin.",
      );
    }
  });

  fullBtn.addEventListener("click", () => {
    // Try to find first video on page (when embedding the site in iframe, this will not find it)
    const v = document.querySelector("video");
    if (v) {
      if (v.requestFullscreen) v.requestFullscreen();
      else if (v.webkitEnterFullScreen) v.webkitEnterFullScreen();
    } else {
      alert(
        "No video element found on this page. When running natively, the app will try to trigger fullscreen on the site.",
      );
    }
  });

  openBtn.addEventListener("click", () => {
    window.location.href = "https://cineby.at";
  });
});
