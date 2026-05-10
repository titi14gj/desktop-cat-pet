let state = null;

const els = {
  currentMediaName: document.getElementById('current-media-name'),
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
  cropEnabled: document.getElementById('crop-enabled'),
  cropZoom: document.getElementById('crop-zoom'),
  cropOffsetX: document.getElementById('crop-offset-x'),
  cropOffsetY: document.getElementById('crop-offset-y'),
  resetCrop: document.getElementById('reset-crop'),
  quit: document.getElementById('quit')
};

function fileName(item) {
  return item?.name || String(item?.path || item).split(/[\\/]/).pop();
}

function mediaPath(item) {
  return item?.path || item;
}

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

function updateState(patch) {
  return window.desktopPet.updateState(patch);
}

function renderList() {
  els.mediaList.innerHTML = '';
  state.media.forEach((item, index) => {
    const li = document.createElement('li');
    li.textContent = fileName(item);
    li.title = mediaPath(item);
    li.className = index === state.currentIndex ? 'selected' : '';
    li.addEventListener('click', () => updateState({ currentIndex: index }));
    els.mediaList.appendChild(li);
  });
}

function renderPreview() {
  const item = currentMedia();
  els.currentMediaName.textContent = item ? fileName(item) : '未选择素材';
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

function renderControls() {
  els.playbackMode.value = state.playbackMode;
  els.rotateSeconds.value = state.rotateSeconds;
  els.petSize.value = state.size;
  els.playSpeed.value = state.speed;
  els.alwaysOnTop.checked = state.alwaysOnTop;
  els.cropEnabled.checked = state.crop.enabled;
  els.cropZoom.value = state.crop.zoom;
  els.cropOffsetX.value = state.crop.offsetX;
  els.cropOffsetY.value = state.crop.offsetY;
}

function render(nextState) {
  state = nextState;
  renderList();
  renderPreview();
  renderControls();
}

async function addMedia() {
  const selected = await window.desktopPet.chooseMedia();
  const media = [...state.media];
  for (const item of selected) {
    if (!media.some((existing) => mediaPath(existing) === mediaPath(item))) media.push(item);
  }
  updateState({
    media,
    currentIndex: state.currentIndex === -1 && media.length > 0 ? 0 : state.currentIndex
  });
}

function removeMedia() {
  if (state.currentIndex < 0) return;
  const media = [...state.media];
  media.splice(state.currentIndex, 1);
  updateState({
    media,
    currentIndex: Math.min(state.currentIndex, media.length - 1)
  });
}

els.addMedia.addEventListener('click', addMedia);
els.removeMedia.addEventListener('click', removeMedia);

els.playbackMode.addEventListener('change', () => {
  updateState({ playbackMode: els.playbackMode.value });
});

els.rotateSeconds.addEventListener('change', () => {
  updateState({ rotateSeconds: Number(els.rotateSeconds.value) || 60 });
});

els.petSize.addEventListener('input', () => {
  updateState({ size: Number(els.petSize.value) });
});

els.playSpeed.addEventListener('input', () => {
  updateState({ speed: Number(els.playSpeed.value) });
});

els.alwaysOnTop.addEventListener('change', () => {
  updateState({ alwaysOnTop: els.alwaysOnTop.checked });
});

els.cropEnabled.addEventListener('change', () => {
  updateState({ crop: { enabled: els.cropEnabled.checked } });
});

els.cropZoom.addEventListener('input', () => {
  updateState({ crop: { zoom: Number(els.cropZoom.value) } });
});

els.cropOffsetX.addEventListener('input', () => {
  updateState({ crop: { offsetX: Number(els.cropOffsetX.value) } });
});

els.cropOffsetY.addEventListener('input', () => {
  updateState({ crop: { offsetY: Number(els.cropOffsetY.value) } });
});

els.resetCrop.addEventListener('click', () => {
  updateState({ crop: { enabled: false, zoom: 1, offsetX: 0, offsetY: 0 } });
});

els.quit.addEventListener('click', () => window.desktopPet.quit());

window.desktopPet.onStateUpdated(render);
window.desktopPet.getState().then(render);
