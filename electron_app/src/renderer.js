let state = null;
let rotateTimer = null;

const els = {
  stage: document.getElementById('stage'),
  imagePlayer: document.getElementById('image-player'),
  videoPlayer: document.getElementById('video-player'),
  emptyState: document.getElementById('empty-state'),
  windowFrame: document.getElementById('window-frame'),
  windowSizeBadge: document.getElementById('window-size-badge'),
  lockBadge: document.getElementById('lock-badge'),
  settingsHotspot: document.getElementById('settings-hotspot')
};

function mediaType(item) {
  return item?.kind || (String(item?.path || item).toLowerCase().endsWith('.webm') ? 'video' : 'image');
}

function mediaSrc(item) {
  return item?.url || `file:///${String(item?.path || item).replace(/\\/g, '/')}`;
}

function currentMedia() {
  if (!state || state.currentIndex < 0 || state.currentIndex >= state.media.length) return null;
  return state.media[state.currentIndex];
}

function applyCrop() {
  const crop = state?.crop || { enabled: false, zoom: 1, offsetX: 0, offsetY: 0 };
  const zoom = crop.enabled ? crop.zoom : 1;
  const offsetX = crop.enabled ? crop.offsetX : 0;
  const offsetY = crop.enabled ? crop.offsetY : 0;
  const transform = `translate(${offsetX}%, ${offsetY}%) scale(${zoom})`;

  for (const player of [els.imagePlayer, els.videoPlayer]) {
    player.style.transform = transform;
    player.style.maxWidth = crop.enabled ? 'none' : '100%';
    player.style.maxHeight = crop.enabled ? 'none' : '100%';
    player.style.width = crop.enabled ? '100%' : '';
    player.style.height = crop.enabled ? '100%' : '';
    player.style.objectFit = crop.enabled ? 'cover' : 'contain';
  }
}

function renderWindowMeta() {
  const size = state?.size || 320;
  els.windowFrame.hidden = !state?.showFrame;
  els.windowSizeBadge.textContent = `${size} x ${size} px`;
  els.lockBadge.hidden = !state?.lockPosition;
  els.stage.classList.toggle('is-locked', Boolean(state?.lockPosition));
}

function renderPlayer() {
  const item = currentMedia();
  els.imagePlayer.hidden = true;
  els.videoPlayer.hidden = true;
  els.emptyState.hidden = Boolean(item);
  els.videoPlayer.pause();
  els.videoPlayer.removeAttribute('src');
  els.imagePlayer.removeAttribute('src');

  if (!item) return;

  if (mediaType(item) === 'video') {
    els.videoPlayer.src = mediaSrc(item);
    els.videoPlayer.playbackRate = state.speed;
    els.videoPlayer.hidden = false;
    els.videoPlayer.play().catch(() => {});
  } else {
    els.imagePlayer.src = mediaSrc(item);
    els.imagePlayer.hidden = false;
  }
}

function restartRotation() {
  clearInterval(rotateTimer);
  rotateTimer = null;
  if (!state || state.playbackMode === 'single' || state.media.length <= 1) return;
  rotateTimer = setInterval(advanceMedia, Math.max(5, state.rotateSeconds) * 1000);
}

function advanceMedia() {
  if (!state || state.media.length <= 1) return;

  let currentIndex = state.currentIndex;
  if (state.playbackMode === 'shuffle') {
    while (currentIndex === state.currentIndex) {
      currentIndex = Math.floor(Math.random() * state.media.length);
    }
  } else if (state.playbackMode === 'sequential') {
    currentIndex = (state.currentIndex + 1) % state.media.length;
  }

  window.desktopPet.updateState({ currentIndex });
}

function render(nextState) {
  const previousPath = currentMedia()?.path;
  state = nextState;
  const nextPath = currentMedia()?.path;
  if (previousPath !== nextPath) renderPlayer();
  els.videoPlayer.playbackRate = state.speed;
  applyCrop();
  renderWindowMeta();
  restartRotation();
}

document.addEventListener('contextmenu', (event) => {
  event.preventDefault();
  window.desktopPet.openSettings();
});

els.settingsHotspot.addEventListener('click', () => {
  window.desktopPet.openSettings();
});

window.desktopPet.onStateUpdated(render);

window.desktopPet.getState().then((nextState) => {
  state = nextState;
  renderPlayer();
  applyCrop();
  renderWindowMeta();
  restartRotation();
});
