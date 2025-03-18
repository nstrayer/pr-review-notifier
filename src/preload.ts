// Preload script for Electron
// This file is loaded before the renderer process

window.addEventListener('DOMContentLoaded', () => {
  // Make app draggable but keep scrolling working
  const appRegion = document.createElement('style');
  appRegion.innerHTML = `
    body * {
      -webkit-app-region: no-drag;
    }
    header {
      -webkit-app-region: drag;
    }
    header button, header input, header a, header svg {
      -webkit-app-region: no-drag;
    }
    .overflow-auto, .overflow-y-auto {
      -webkit-app-region: no-drag !important;
    }
    #scrollable-content {
      -webkit-app-region: no-drag !important;
    }
  `;
  document.head.appendChild(appRegion);
  
  // Fix for scrollbars being draggable
  setTimeout(() => {
    const scrollable = document.getElementById('scrollable-content');
    if (scrollable) {
      // Make sure scrollbar is interactive
      (scrollable as HTMLElement).setAttribute('style', '-webkit-app-region: no-drag');
      Array.from(scrollable.querySelectorAll('*')).forEach(el => {
        (el as HTMLElement).setAttribute('style', '-webkit-app-region: no-drag');
      });
    }
  }, 500);
});