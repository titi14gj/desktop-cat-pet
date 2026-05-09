const STORAGE_KEY = 'desktop-cat-pet-windows-state';

const state = {
  media: [],
  currentIndex: -1,
  playbackMode: 'single',
  rotateSeconds: 60,
  size: 320,
  speed: 1,
  alwaysOnTop: true
};

let rotateTimer = null;

const els = {
  settings: document.getElementById('settings'),
  imagePlayer: document.getElementById('image-player'),
  videoPlayer: document.getElementById('video-player'),
  emptyState: document.getElementById('empty-state'),
  mediaList: document.getElementById('media-list'),
  previewImage: document.getElementById('preview-image'),
  previewVideo: document.getElementById('preview-video'),
  addMedia: document.getElementById('add-media'),
  removeMedia: document.getElementById('remove-media'),
  playbackMode: document.getElementById('playback-mode'),
  rotateSeconds: document.getElementById('rotate-seconds'),
  petSize: document.getElementById('pet-size'),
  playSpeed: document.getElementById('play-speed'),
  alwaysOnTop: document.getElementById('always-on-top'),
  closeSettings: document.getElementById('close-settings'),
  quit: document.getElementById('quit')
};

function loadState() {
  try {
    Object.assign(state, JSON.parse(localStorage.getItem(STORAGE_KEY)) || {});
  } catch {
    // Keep defaults.
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function fileName(filePath) {
  return filePath.split(/[\\/]/).pop();
}

function mediaType(filePath) {
  const ext = filePath.split('.').pop().toLowerCase();
  if (ext === 'webm') return 'video';
  return 'image';
}

function mediaSrc(filePath) {
  return `file:///${filePath.replace(/\\/g, '/')}`;
}

function currentMedia() {
  if (state.currentIndex < 0 || state.currentIndex >= state.media.length) return null;
  return state.media[state.currentIndex];
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

function renderList() {
  els.mediaList.innerHTML = '';
  state.media.forEach((item, index) => {
    const li = document.createElement('li');
    li.textContent = fileName(item);
    li.title = item;
    li.className = index === state.currentIndex ? 'selected' : '';
    li.addEventListener('click', () => {
      state.currentIndex = index;
      saveState();
      renderAll();
    });
    els.mediaList.appendChild(li);
  });
}

function renderPreview() {
  const item = currentMedia();
  els.previewImage.hidden = true;
  els.previewVideo.hidden = true;
  els.previewVideo.pause();
  els.previewVideo.removeAttribute('src');
  els.previewImage.removeAttribute('src');
  if (!item) return;

  if (mediaType(item) === 'video') {
    els.previewVideo.src = mediaSrc(item);
    els.previewVideo.hidden = false;
    els.previewVideo.play().catch(() => {});
  } else {
    els.previewImage.src = mediaSrc(item);
    els.previewImage.hidden = false;
  }
}

function restartRotation() {
  clearInterval(rotateTimer);
  rotateTimer = null;
  if (state.playbackMode === 'single' || state.media.length <= 1) return;
  rotateTimer = setInterval(advanceMedia, Math.max(5, state.rotateSeconds) * 1000);
}

function advanceMedia() {
  if (state.media.length <= 1) return;
  if (state.playbackMode === 'shuffle') {
    let next = state.currentIndex;
    while (next === state.currentIndex) {
      next = Math.floor(Math.random() * state.media.length);
    }
    state.currentIndex = next;
  } else if (state.playbackMode === 'sequential') {
    state.currentIndex = (state.currentIndex + 1) % state.media.length;
  }
  saveState();
  renderAll();
}

function renderControls() {
  els.playbackMode.value = state.playbackMode;
  els.rotateSeconds.value = state.rotateSeconds;
  els.petSize.value = state.size;
  els.playSpeed.value = state.speed;
  els.alwaysOnTop.checked = state.alwaysOnTop;
}

function renderAll() {
  renderPlayer();
  renderList();
  renderPreview();
  renderControls();
  restartRotation();
}

async function addMedia() {
  const selected = await window.desktopPet.chooseMedia();
  for (const item of selected) {
    if (!state.media.includes(item)) state.media.push(item);
  }
  if (state.currentIndex === -1 && state.media.length > 0) state.currentIndex = 0;
  saveState();
  renderAll();
}

function removeMedia() {
  if (state.currentIndex < 0) return;
  state.media.splice(state.currentIndex, 1);
  state.currentIndex = Math.min(state.currentIndex, state.media.length - 1);
  saveState();
  renderAll();
}

document.addEventListener('contextmenu', (event) => {
  event.preventDefault();
  els.settings.hidden = false;
});

els.closeSettings.addEventListener('click', () => {
  els.settings.hidden = true;
});

els.addMedia.addEventListener('click', addMedia);
els.removeMedia.addEventListener('click', removeMedia);

els.playbackMode.addEventListener('change', () => {
  state.playbackMode = els.playbackMode.value;
  saveState();
  restartRotation();
});

els.rotateSeconds.addEventListener('change', () => {
  state.rotateSeconds = Math.max(5, Number(els.rotateSeconds.value) || 60);
  saveState();
  restartRotation();
});

els.petSize.addEventListener('input', () => {
  state.size = Number(els.petSize.value);
  saveState();
  window.desktopPet.setWindowSize(state.size);
});

els.playSpeed.addEventListener('input', () => {
  state.speed = Number(els.playSpeed.value);
  els.videoPlayer.playbackRate = state.speed;
  saveState();
});

els.alwaysOnTop.addEventListener('change', () => {
  state.alwaysOnTop = els.alwaysOnTop.checked;
  saveState();
  window.desktopPet.setAlwaysOnTop(state.alwaysOnTop);
});

els.quit.addEventListener('click', () => window.desktopPet.quit());

loadState();
window.desktopPet.setWindowSize(state.size);
window.desktopPet.setAlwaysOnTop(state.alwaysOnTop);
renderAll();
