/**
 * Soko Photo Editor - Core Editor Logic
 * A professional photo editor built with Fabric.js
 * 
 * Features:
 * - Crop & Rotate
 * - Filters & Effects
 * - Adjustments (brightness, contrast, saturation, etc.)
 * - Text overlay
 * - Drawing tools
 * - Shapes
 * - Layers management
 * - Background removal (AI-powered)
 * - Undo/Redo history
 */

// ============================================
// FILTER PRESETS
// ============================================
const FILTER_PRESETS = [
    { name: 'None', filters: [] },
    { name: 'Soko Premium', filters: [{ type: 'Brightness', brightness: 0.03 }, { type: 'Contrast', contrast: 0.12 }, { type: 'Saturation', saturation: 0.2 }] },
    { name: 'Vivid', filters: [{ type: 'Saturation', saturation: 0.3 }, { type: 'Contrast', contrast: 0.1 }] },
    { name: 'Pop', filters: [{ type: 'Brightness', brightness: 0.02 }, { type: 'Contrast', contrast: 0.18 }, { type: 'Saturation', saturation: 0.15 }] },
    { name: 'Sharpen', filters: [{ type: 'Convolute', matrix: [0, -1, 0, -1, 5, -1, 0, -1, 0] }] },
    { name: 'Warm', filters: [{ type: 'Brightness', brightness: 0.05 }, { type: 'HueRotation', rotation: -0.05 }] },
    { name: 'Cool', filters: [{ type: 'HueRotation', rotation: 0.1 }, { type: 'Saturation', saturation: -0.1 }] },
    { name: 'B&W', filters: [{ type: 'Grayscale' }] },
    { name: 'Sepia', filters: [{ type: 'Sepia' }] },
    { name: 'Vintage', filters: [{ type: 'Sepia' }, { type: 'Noise', noise: 50 }, { type: 'Contrast', contrast: -0.1 }] },
    { name: 'Fade', filters: [{ type: 'Contrast', contrast: -0.2 }, { type: 'Saturation', saturation: -0.3 }] },
    { name: 'Drama', filters: [{ type: 'Contrast', contrast: 0.3 }, { type: 'Saturation', saturation: 0.2 }] },
    { name: 'Noir', filters: [{ type: 'Grayscale' }, { type: 'Contrast', contrast: 0.3 }] },
    { name: 'Invert', filters: [{ type: 'Invert' }] },
    { name: 'Blur', filters: [{ type: 'Blur', blur: 0.2 }] },
];

function safeCreateIcons() {
    try {
        globalThis.lucide?.createIcons?.();
    } catch (e) {
        // noop
    }
}

function ensurePhotoEditorDeps() {
    const missing = [];
    if (!globalThis.fabric) missing.push('Fabric.js');
    if (!globalThis.lucide) missing.push('Lucide Icons');

    if (!missing.length) return true;

    const message = `Photo Editor failed to load required dependencies: ${missing.join(', ')}.`;
    const overlay = document.createElement('div');
    overlay.style.position = 'fixed';
    overlay.style.inset = '0';
    overlay.style.zIndex = '99999';
    overlay.style.background = '#0d0d0f';
    overlay.style.color = '#fafafa';
    overlay.style.display = 'flex';
    overlay.style.alignItems = 'center';
    overlay.style.justifyContent = 'center';
    overlay.style.padding = '24px';
    overlay.style.textAlign = 'center';
    overlay.innerHTML = `<div><h2 style="margin:0 0 8px;font-size:18px;">${message}</h2><p style="margin:0;opacity:.8;font-size:13px;">Please refresh the page. If it persists, contact support.</p></div>`;
    document.body.appendChild(overlay);
    return false;
}

function clampInt(value, min, max) {
    return value < min ? min : value > max ? max : value;
}

function colorDistanceSq(a, b) {
    const dr = a.r - b.r;
    const dg = a.g - b.g;
    const db = a.b - b.b;
    return dr * dr + dg * dg + db * db;
}

function averageRegionColor(data, width, height, startX, startY, regionSize = 18) {
    const x0 = clampInt(startX, 0, Math.max(0, width - 1));
    const y0 = clampInt(startY, 0, Math.max(0, height - 1));
    const x1 = clampInt(x0 + regionSize, 0, width);
    const y1 = clampInt(y0 + regionSize, 0, height);

    let r = 0;
    let g = 0;
    let b = 0;
    let count = 0;

    for (let y = y0; y < y1; y++) {
        let row = y * width * 4;
        for (let x = x0; x < x1; x++) {
            const i = row + x * 4;
            const a = data[i + 3];
            if (a === 0) continue;
            r += data[i];
            g += data[i + 1];
            b += data[i + 2];
            count++;
        }
    }

    if (!count) return { r: 255, g: 255, b: 255 };
    return {
        r: Math.round(r / count),
        g: Math.round(g / count),
        b: Math.round(b / count),
    };
}

function pickDominantCornerColor(corners) {
    if (!corners.length) return { r: 255, g: 255, b: 255 };
    if (corners.length === 1) return corners[0];

    let bestIndex = 0;
    let bestScore = Number.POSITIVE_INFINITY;
    for (let i = 0; i < corners.length; i++) {
        let score = 0;
        for (let j = 0; j < corners.length; j++) {
            if (i === j) continue;
            score += colorDistanceSq(corners[i], corners[j]);
        }
        if (score < bestScore) {
            bestScore = score;
            bestIndex = i;
        }
    }

    return corners[bestIndex];
}

function buildBackgroundMask(imageData, width, height, bgColor, tolerance) {
    const data = imageData.data;
    const total = width * height;
    const toleranceSq = tolerance * tolerance;

    const seen = new Uint8Array(total);
    const bg = new Uint8Array(total);
    const queue = new Uint32Array(total);
    let head = 0;
    let tail = 0;

    const push = (index) => {
        if (seen[index]) return;
        seen[index] = 1;
        queue[tail++] = index;
    };

    for (let x = 0; x < width; x++) {
        push(x);
        push((height - 1) * width + x);
    }
    for (let y = 0; y < height; y++) {
        push(y * width);
        push(y * width + (width - 1));
    }

    const isBg = (index) => {
        const i = index * 4;
        const a = data[i + 3];
        if (a === 0) return false;
        const dr = data[i] - bgColor.r;
        const dg = data[i + 1] - bgColor.g;
        const db = data[i + 2] - bgColor.b;
        const distSq = dr * dr + dg * dg + db * db;
        return distSq <= toleranceSq;
    };

    while (head < tail) {
        const index = queue[head++];
        if (!isBg(index)) continue;

        bg[index] = 1;

        const y = (index / width) | 0;
        const x = index - y * width;

        if (x > 0) push(index - 1);
        if (x < width - 1) push(index + 1);
        if (y > 0) push(index - width);
        if (y < height - 1) push(index + width);
    }

    return bg;
}

function blurAlphaChannel(alpha, width, height, radius) {
    if (!radius || radius < 1) return alpha;

    const r = Math.min(20, radius | 0);
    const windowSize = r * 2 + 1;
    const tmp = new Uint8ClampedArray(alpha.length);
    const out = new Uint8ClampedArray(alpha.length);

    for (let y = 0; y < height; y++) {
        const rowOffset = y * width;
        let sum = 0;

        for (let x = -r; x <= r; x++) {
            sum += alpha[rowOffset + clampInt(x, 0, width - 1)];
        }

        for (let x = 0; x < width; x++) {
            tmp[rowOffset + x] = Math.round(sum / windowSize);

            const removeX = clampInt(x - r, 0, width - 1);
            const addX = clampInt(x + r + 1, 0, width - 1);
            sum += alpha[rowOffset + addX] - alpha[rowOffset + removeX];
        }
    }

    for (let x = 0; x < width; x++) {
        let sum = 0;

        for (let y = -r; y <= r; y++) {
            sum += tmp[clampInt(y, 0, height - 1) * width + x];
        }

        for (let y = 0; y < height; y++) {
            out[y * width + x] = Math.round(sum / windowSize);

            const removeY = clampInt(y - r, 0, height - 1);
            const addY = clampInt(y + r + 1, 0, height - 1);
            sum += tmp[addY * width + x] - tmp[removeY * width + x];
        }
    }

    return out;
}

// ============================================
// MAIN EDITOR CLASS
// ============================================
class SokoPhotoEditor {
    constructor() {
        this.canvas = null;
        this.originalImage = null;
        this.currentImage = null;
        this.history = [];
        this.historyIndex = -1;
        this.maxHistory = 50;
        this.savedHistoryIndex = -1;
        this.currentTool = 'select';
        this.zoom = 1;
        this.isCropping = false;
        this.cropRect = null;
        this.adjustments = {
            brightness: 0,
            contrast: 0,
            saturation: 0,
            hue: 0,
            blur: 0,
            noise: 0
        };
        this.currentFilter = 'None';
        this.isDrawing = false;
        this.brushSettings = {
            type: 'brush',
            size: 10,
            color: '#0f172a',
            opacity: 100
        };
        this.shapeSettings = {
            fill: '#009ef7',
            stroke: '#0f172a',
            strokeWidth: 2
        };
        this.textSettings = {
            fontFamily: 'system-ui',
            fontSize: 32,
            fill: '#0f172a',
            bold: false,
            italic: false,
            underline: false
        };

        this.hasUnsavedChanges = false;
        this.csrfToken = null;
        this.defaultPickerTimer = null;
        this.draftPromptedForFileId = null;
        this.bgRemoveSettings = { tolerance: 32, feather: 2 };
        try {
            const stored = JSON.parse(localStorage.getItem('soko-photo-editor:bg-settings') || 'null');
            if (stored && typeof stored === 'object') {
                if (Number.isFinite(Number(stored.tolerance))) this.bgRemoveSettings.tolerance = Number(stored.tolerance);
                if (Number.isFinite(Number(stored.feather))) this.bgRemoveSettings.feather = Number(stored.feather);
            }
        } catch (e) {
            // noop
        }
        
        this.init();
    }
    
    // ============================================
    // INITIALIZATION
    // ============================================
    init() {
        this.setupCanvas();
        this.setupEventListeners();
        this.setupDropZone();
        this.setupToolbar();
        this.setupKeyboardShortcuts();
        this.setupUploadsPicker();
        this.setupMessageBridge();
        
        // Initialize Lucide icons
        safeCreateIcons();
        
        // Check for URL parameter (image to edit)
        this.checkUrlParams();
    }

    setupMessageBridge() {
        window.addEventListener('message', (event) => {
            if (event.origin !== window.location.origin) return;

            const data = event.data || {};
            if (data.type !== 'soko-photo-editor:open') return;

            if (this.defaultPickerTimer) {
                clearTimeout(this.defaultPickerTimer);
                this.defaultPickerTimer = null;
            }

            const imageUrl = data.imageUrl || null;
            const fileId = data.fileId || null;
            const fileName = data.fileName || null;
            const picker = !!data.picker;

            try {
                const nextUrl = new URL(window.location.href);
                nextUrl.searchParams.delete('image');
                nextUrl.searchParams.delete('file_id');
                nextUrl.searchParams.delete('file_name');
                nextUrl.searchParams.delete('picker');
                if (imageUrl) nextUrl.searchParams.set('image', imageUrl);
                if (fileId) nextUrl.searchParams.set('file_id', fileId);
                if (fileName) nextUrl.searchParams.set('file_name', fileName);
                if (!imageUrl && picker) nextUrl.searchParams.set('picker', '1');
                window.history.replaceState(null, '', nextUrl.toString());
            } catch (e) {
                // noop
            }

            if (fileId) {
                this.originalFileId = fileId;
                this.originalFileName = fileName || 'Original file';
            } else {
                this.originalFileId = null;
                this.originalFileName = null;
            }

            if (fileId) {
                this.loadImageFromFileId(fileId, imageUrl);
            } else if (imageUrl) {
                this.loadImageFromUrl(imageUrl);
            } else if (picker) {
                this.showUploadsModal();
            }

            if (fileId || imageUrl) {
                this.hideUploadsModal();
            }
        });
    }
    
    setupCanvas() {
        const container = document.getElementById('canvas-container');
        const canvasElement = document.getElementById('editor-canvas');
        
        // Create Fabric.js canvas
        this.canvas = new fabric.Canvas('editor-canvas', {
            backgroundColor: 'transparent',
            selection: true,
            preserveObjectStacking: true
        });
        
        // Handle object selection
        this.canvas.on('selection:created', () => this.updateLayersPanel());
        this.canvas.on('selection:updated', () => this.updateLayersPanel());
        this.canvas.on('selection:cleared', () => this.updateLayersPanel());
        this.canvas.on('object:modified', () => this.saveState());
        this.canvas.on('object:added', () => this.updateLayersPanel());
        this.canvas.on('object:removed', () => this.updateLayersPanel());
    }
    
    setupEventListeners() {
        // Tool buttons
        document.querySelectorAll('.sidebar-tool').forEach(btn => {
            btn.addEventListener('click', () => this.selectTool(btn.dataset.tool));
        });
        
        // Undo/Redo
        document.getElementById('btn-undo')?.addEventListener('click', () => this.undo());
        document.getElementById('btn-redo')?.addEventListener('click', () => this.redo());
        
        // Zoom controls
        document.getElementById('btn-zoom-in')?.addEventListener('click', () => this.zoomIn());
        document.getElementById('btn-zoom-out')?.addEventListener('click', () => this.zoomOut());
        document.getElementById('btn-zoom-fit')?.addEventListener('click', () => this.zoomFit());
        
        // Reset and Export
        document.getElementById('btn-reset')?.addEventListener('click', () => this.resetImage());
        document.getElementById('btn-export')?.addEventListener('click', () => this.showExportModal());
        document.getElementById('btn-auto-enhance')?.addEventListener('click', () => this.autoEnhance());
        
        // Export modal
        document.getElementById('modal-close')?.addEventListener('click', () => this.hideExportModal());
        document.getElementById('btn-cancel-export')?.addEventListener('click', () => this.hideExportModal());
        document.getElementById('btn-download')?.addEventListener('click', () => this.downloadImage());
        (document.getElementById('btn-save-to-server') || document.getElementById('btn-save-to-uploads'))?.addEventListener('click', () => this.saveToServer());
        
        // Format buttons
        document.querySelectorAll('.format-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.format-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                
                // Show/hide quality slider for lossy formats
                const qualityGroup = document.getElementById('quality-group');
                qualityGroup.style.display = ['jpeg', 'webp'].includes(btn.dataset.format) ? 'block' : 'none';
            });
        });
        
        // Quality slider
        document.getElementById('export-quality')?.addEventListener('input', (e) => {
            const valueLabel = document.getElementById('quality-value');
            if (valueLabel) {
                valueLabel.textContent = e.target.value + '%';
            }
        });
        
        // Modal backdrop click
        document.querySelector('#export-modal .modal-backdrop')?.addEventListener('click', () => this.hideExportModal());
    }
    
    setupDropZone() {
        const dropZone = document.getElementById('drop-zone');
        const fileInput = document.getElementById('file-input');
        const browseBtn = document.getElementById('btn-browse');
        
        if (!dropZone || !fileInput || !browseBtn) {
            return;
        }
        
        // Click to browse
        browseBtn.addEventListener('click', () => fileInput.click());
        dropZone.addEventListener('click', (e) => {
            if (e.target === dropZone || e.target.closest('.drop-zone-content')) {
                fileInput.click();
            }
        });
        
        // File input change
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                this.loadImageFromFile(e.target.files[0]);
            }
        });
        
        // Drag and drop
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('drag-over');
        });
        
        dropZone.addEventListener('dragleave', () => {
            dropZone.classList.remove('drag-over');
        });
        
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('drag-over');
            
            if (e.dataTransfer.files.length > 0) {
                this.loadImageFromFile(e.dataTransfer.files[0]);
            }
        });
    }
    
    setupToolbar() {
        // Set up tool-specific panels will be loaded dynamically
    }
    
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            const isInputFocused = document.activeElement.tagName === 'INPUT' || 
                                   document.activeElement.tagName === 'TEXTAREA';
            
            // Undo: Ctrl+Z
            if (e.ctrlKey && e.key === 'z' && !e.shiftKey) {
                e.preventDefault();
                this.undo();
            }
            // Redo: Ctrl+Y or Ctrl+Shift+Z
            if ((e.ctrlKey && e.key === 'y') || (e.ctrlKey && e.shiftKey && e.key === 'z')) {
                e.preventDefault();
                this.redo();
            }
            // Save: Ctrl+S
            if (e.ctrlKey && e.key === 's') {
                e.preventDefault();
                this.showExportModal();
            }
            // Open uploads: Ctrl+O
            if (e.ctrlKey && (e.key === 'o' || e.key === 'O')) {
                e.preventDefault();
                this.showUploadsModal();
            }
            // Download: Ctrl+D
            if (e.ctrlKey && e.key === 'd') {
                e.preventDefault();
                this.downloadImage();
            }
            // Zoom In: Ctrl++
            if (e.ctrlKey && (e.key === '+' || e.key === '=')) {
                e.preventDefault();
                this.zoomIn();
            }
            // Zoom Out: Ctrl+-
            if (e.ctrlKey && e.key === '-') {
                e.preventDefault();
                this.zoomOut();
            }
            // Fit to Screen: Ctrl+0
            if (e.ctrlKey && e.key === '0') {
                e.preventDefault();
                this.zoomFit();
            }
            // Delete selected object
            if (e.key === 'Delete' || e.key === 'Backspace') {
                if (!isInputFocused) {
                    e.preventDefault();
                    this.deleteSelected();
                }
            }
            // Escape: deselect all / cancel
            if (e.key === 'Escape') {
                this.canvas.discardActiveObject();
                this.canvas.renderAll();
                if (this.isCropping || this.isResizing) {
                    this.cancelResize();
                }
                this.hideShortcutsModal();
                this.hideUploadsModal();
            }
            
            // Tool shortcuts (only when not typing)
            if (!isInputFocused) {
                // ? - Show shortcuts
                if (e.key === '?' || (e.shiftKey && e.key === '/')) {
                    e.preventDefault();
                    this.showShortcutsModal();
                }
                // V - Select tool
                if (e.key === 'v' || e.key === 'V') {
                    this.selectTool('select');
                }
                // R - Resize tool
                if (e.key === 'r' || e.key === 'R') {
                    this.selectTool('resize');
                }
                // T - Text tool
                if (e.key === 't' || e.key === 'T') {
                    this.selectTool('text');
                }
                // B - Brush/Draw tool
                if (e.key === 'b' || e.key === 'B') {
                    this.selectTool('draw');
                }
                // E - Eraser
                if (e.key === 'e' || e.key === 'E') {
                    this.selectTool('draw');
                    setTimeout(() => {
                        document.querySelector('[data-draw="eraser"]')?.click();
                    }, 100);
                }
                // L - Layers
                if (e.key === 'l' || e.key === 'L') {
                    this.selectTool('layers');
                }
                // Layer shortcuts
                if (e.ctrlKey && e.key === ']') {
                    e.preventDefault();
                    this.bringForward();
                }
                if (e.ctrlKey && e.key === '[') {
                    e.preventDefault();
                    this.sendBackward();
                }
                if (e.ctrlKey && e.key === 'j') {
                    e.preventDefault();
                    this.duplicateSelected();
                }
            }
        });
        
        // Space + drag for panning
        document.addEventListener('keydown', (e) => {
            if (e.code === 'Space' && !this.isPanning) {
                this.isPanning = true;
                this.canvas.defaultCursor = 'grab';
                this.canvas.hoverCursor = 'grab';
            }
        });
        
        document.addEventListener('keyup', (e) => {
            if (e.code === 'Space') {
                this.isPanning = false;
                this.canvas.defaultCursor = 'default';
                this.canvas.hoverCursor = 'move';
            }
        });
        
        // Shortcuts modal button
        document.getElementById('btn-shortcuts')?.addEventListener('click', () => {
            this.showShortcutsModal();
        });
        
        document.getElementById('shortcuts-close')?.addEventListener('click', () => {
            this.hideShortcutsModal();
        });
        
        // Close shortcuts modal on backdrop click
        document.querySelector('#shortcuts-modal .modal-backdrop')?.addEventListener('click', () => {
            this.hideShortcutsModal();
        });
    }
    
    showShortcutsModal() {
        document.getElementById('shortcuts-modal')?.classList.remove('hidden');
        safeCreateIcons();
    }
    
    hideShortcutsModal() {
        document.getElementById('shortcuts-modal')?.classList.add('hidden');
    }
    
    checkUrlParams() {
        const urlParams = new URLSearchParams(window.location.search);
        const imageUrl = urlParams.get('image');
        const showPicker = urlParams.get('picker') === '1';
        const fileId = urlParams.get('file_id');
        const fileName = urlParams.get('file_name');
        
        if (fileId) {
            this.originalFileId = fileId;
            if (fileName) this.originalFileName = fileName;
            const filenameInput = document.getElementById('export-filename');
            if (filenameInput && fileName) filenameInput.value = fileName;
            this.loadImageFromFileId(fileId, imageUrl);
        } else if (imageUrl) {
            this.loadImageFromUrl(imageUrl);
        } else if (showPicker) {
            this.showUploadsModal();
        } else if (window.self === window.top) {
            this.showUploadsModal();
        } else {
            this.defaultPickerTimer = setTimeout(() => {
                const dropZone = document.getElementById('drop-zone');
                if (!this.currentImage && dropZone && !dropZone.classList.contains('hidden')) {
                    this.showUploadsModal();
                }
            }, 600);
        }
    }

    async loadImageFromFileId(fileId, fallbackUrl = null) {
        try {
            const baseUrl = window.location.origin;
            const response = await fetch(`${baseUrl}/photo-editor/file-info/${fileId}`, {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });

            if (!response.ok) {
                throw new Error('Failed to fetch file info');
            }

            const payload = await response.json();
            if (payload?.url) {
                this.loadImageFromUrl(payload.url);
                return;
            }
        } catch (error) {
            console.error('File info error:', error);
        }

        if (fallbackUrl) {
            this.loadImageFromUrl(fallbackUrl);
        } else {
            this.showToast('Unable to load the selected image.', 'error');
        }
    }

    // ============================================
    // UPLOADS PICKER
    // ============================================
    setupUploadsPicker() {
        this.uploadsPicker = {
            search: '',
            sort: 'newest',
            nextUrl: null,
            prevUrl: null
        };

        document.getElementById('btn-my-uploads')?.addEventListener('click', () => {
            this.showUploadsModal();
        });

        document.getElementById('uploads-close')?.addEventListener('click', () => {
            this.hideUploadsModal();
        });

        document.querySelector('#uploads-modal .modal-backdrop')?.addEventListener('click', () => {
            this.hideUploadsModal();
        });

        const searchInput = document.getElementById('uploads-search');
        const sortSelect = document.getElementById('uploads-sort');
        const prevBtn = document.getElementById('uploads-prev');
        const nextBtn = document.getElementById('uploads-next');

        const debouncedSearch = this.debounce(() => {
            this.uploadsPicker.search = (searchInput?.value || '').trim();
            this.fetchUploadsPage();
        }, 250);

        searchInput?.addEventListener('input', debouncedSearch);
        sortSelect?.addEventListener('change', () => {
            this.uploadsPicker.sort = sortSelect.value || 'newest';
            this.fetchUploadsPage();
        });

        prevBtn?.addEventListener('click', () => {
            if (this.uploadsPicker.prevUrl) this.fetchUploadsPage(this.uploadsPicker.prevUrl);
        });

        nextBtn?.addEventListener('click', () => {
            if (this.uploadsPicker.nextUrl) this.fetchUploadsPage(this.uploadsPicker.nextUrl);
        });
    }

    showUploadsModal() {
        document.getElementById('uploads-modal')?.classList.remove('hidden');
        safeCreateIcons();
        this.fetchUploadsPage();
        setTimeout(() => document.getElementById('uploads-search')?.focus(), 50);
    }

    hideUploadsModal() {
        document.getElementById('uploads-modal')?.classList.add('hidden');
    }

    async fetchUploadsPage(url = null) {
        const grid = document.getElementById('uploads-grid');
        const prevBtn = document.getElementById('uploads-prev');
        const nextBtn = document.getElementById('uploads-next');

        if (grid) {
            grid.innerHTML = '<div class="uploads-empty">Loading...</div>';
        }

        try {
            const baseUrl = window.location.origin;
            const requestUrl = url
                ? url
                : (() => {
                    const u = new URL('/photo-editor/uploads', baseUrl);
                    u.searchParams.set('sort', this.uploadsPicker.sort || 'newest');
                    if (this.uploadsPicker.search) u.searchParams.set('search', this.uploadsPicker.search);
                    return u.toString();
                })();

            const response = await fetch(requestUrl, {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });

            const contentType = response.headers.get('content-type') || '';
            if (!response.ok || !contentType.includes('application/json')) {
                throw new Error('Failed to load uploads');
            }

            const payload = await response.json();
            const files = Array.isArray(payload?.data) ? payload.data : [];

            this.uploadsPicker.nextUrl = payload?.next_page_url || null;
            this.uploadsPicker.prevUrl = payload?.prev_page_url || null;

            if (prevBtn) prevBtn.disabled = !this.uploadsPicker.prevUrl;
            if (nextBtn) nextBtn.disabled = !this.uploadsPicker.nextUrl;

            if (!grid) return;

            if (!files.length) {
                grid.innerHTML = '<div class="uploads-empty">No images found</div>';
                return;
            }

            grid.innerHTML = '';
            files.forEach((file) => {
                const item = document.createElement('div');
                item.className = 'uploads-item';

                const name = file.file_original_name || 'Untitled';
                const extension = (file.extension || '').toUpperCase();
                const size = this.bytesToSize(file.file_size || 0);
                const url = file.url;
                const editorUrl = new URL('/photo-editor/', window.location.origin);
                editorUrl.searchParams.set('image', url);
                editorUrl.searchParams.set('file_id', file.id);
                editorUrl.searchParams.set('file_name', name);

                item.innerHTML = `
                    <div class="uploads-item-thumb">
                        <img src="${this.escapeHtml(url)}" alt="${this.escapeHtml(name)}">
                        <div class="uploads-item-actions">
                            <button type="button" class="uploads-action-btn uploads-action-primary" data-action="edit">
                                <i data-lucide="edit-3"></i>
                                Edit
                            </button>
                            <a class="uploads-action-btn" href="${this.escapeHtml(editorUrl.toString())}" target="_blank" rel="noopener">
                                <i data-lucide="external-link"></i>
                            </a>
                        </div>
                    </div>
                    <div class="uploads-item-meta">
                        <div class="uploads-item-name">${this.escapeHtml(name)}</div>
                        <div class="uploads-item-sub">${this.escapeHtml(extension)} • ${this.escapeHtml(size)}</div>
                    </div>
                `;

                const loadIntoEditor = () => {
                    if (!url) return;
                    this.originalFileId = file.id;
                    this.originalFileName = name;
                    const filenameInput = document.getElementById('export-filename');
                    if (filenameInput && name) {
                        filenameInput.value = name;
                    }
                    this.loadImageFromUrl(url);
                    this.hideUploadsModal();
                };

                item.addEventListener('click', loadIntoEditor);
                item.querySelector('[data-action="edit"]')?.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    loadIntoEditor();
                });

                grid.appendChild(item);
            });
            safeCreateIcons();
        } catch (error) {
            console.error('Uploads picker error:', error);
            if (grid) grid.innerHTML = '<div class="uploads-empty">Unable to load uploads. Please make sure you are logged in.</div>';
            if (prevBtn) prevBtn.disabled = true;
            if (nextBtn) nextBtn.disabled = true;
        }
    }

    debounce(fn, delayMs = 200) {
        let timer = null;
        return (...args) => {
            if (timer) clearTimeout(timer);
            timer = setTimeout(() => fn.apply(this, args), delayMs);
        };
    }

    escapeHtml(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    bytesToSize(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        if (!bytes || bytes === 0) return '0 B';
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        const value = bytes / Math.pow(1024, i);
        return `${value.toFixed(value >= 10 || i === 0 ? 0 : 1)} ${sizes[i]}`;
    }

    autoEnhance() {
        if (!this.currentImage) return;

        const preset = FILTER_PRESETS.find(p => p.name === 'Soko Premium') || FILTER_PRESETS.find(p => p.name === 'Pop');
        if (preset) {
            this.applyFilter(preset);
            this.showToast('Auto enhanced', 'success');
        }
    }
    
    // ============================================
    // IMAGE LOADING
    // ============================================
    loadImageFromFile(file) {
        if (!file.type.startsWith('image/')) {
            alert('Please select an image file.');
            return;
        }
        
        this.showLoading();
        
        const reader = new FileReader();
        reader.onload = (e) => {
            this.loadImageFromUrl(e.target.result);
        };
        reader.onerror = () => {
            this.hideLoading();
            alert('Error reading file.');
        };
        reader.readAsDataURL(file);
    }
    
    loadImageFromUrl(url) {
        this.showLoading();

        const normalizedUrl = this.normalizeImageUrl(url);
        const cacheBustedUrl = (() => {
            try {
                const u = new URL(normalizedUrl, window.location.origin);
                u.searchParams.set('_t', Date.now().toString());
                if (u.origin === window.location.origin) {
                    return `${u.pathname}${u.search}${u.hash}`;
                }
                return u.toString();
            } catch (e) {
                if (typeof normalizedUrl === 'string' && normalizedUrl.startsWith('data:')) return normalizedUrl;
                return `${normalizedUrl}${normalizedUrl.includes('?') ? '&' : '?'}_t=${Date.now()}`;
            }
        })();

        const tryLoad = (useCrossOrigin = true) => {
            const img = new Image();
            if (useCrossOrigin) img.crossOrigin = 'anonymous';

            img.onload = () => {
                this.hideLoading();

                const fabricImg = new fabric.Image(img, {
                    left: 0,
                    top: 0,
                    selectable: false,
                    evented: false,
                    name: 'Background Image',
                    isBackgroundImage: true
                });

                // Store original
                this.originalImage = fabricImg;

                // Calculate canvas size
                const canvasArea = document.querySelector('.canvas-area');
                const bounds = canvasArea?.getBoundingClientRect?.();
                const availableWidth = Math.max(320, (bounds?.width || 0) - 80);
                const availableHeight = Math.max(320, (bounds?.height || 0) - 80);

                let scale = 1;
                if (fabricImg.width > availableWidth || fabricImg.height > availableHeight) {
                    scale = Math.min(availableWidth / fabricImg.width, availableHeight / fabricImg.height);
                }

                const canvasWidth = fabricImg.width * scale;
                const canvasHeight = fabricImg.height * scale;

                this.canvas.setZoom(1);
                this.zoom = 1;
                this.canvas.setWidth(Math.max(1, canvasWidth));
                this.canvas.setHeight(Math.max(1, canvasHeight));

                fabricImg.scale(scale);

                this.canvas.clear();
                this.canvas.add(fabricImg);
                this.currentImage = fabricImg;

                document.getElementById('drop-zone').classList.add('hidden');
                document.getElementById('canvas-container').classList.remove('hidden');
                this.hideUploadsModal();

                this.history = [];
                this.historyIndex = -1;
                this.saveState(true);

                this.updateLayersPanel();
                this.updateHistoryButtons();
                this.maybeOfferDraftRestore();
            };

            img.onerror = () => {
                if (useCrossOrigin) {
                    tryLoad(false);
                } else {
                    this.hideLoading();
                    this.showToast('Error loading image. Please try again.', 'error');
                }
            };

            img.src = cacheBustedUrl;
        };

        tryLoad(true);
    }

    normalizeImageUrl(url) {
        try {
            const parsed = new URL(url, window.location.origin);
            if (parsed.hostname === window.location.hostname) {
                parsed.protocol = window.location.protocol;
                parsed.port = window.location.port;
            }

            if (parsed.origin === window.location.origin) {
                return `${parsed.pathname}${parsed.search}${parsed.hash}`;
            }
            return parsed.toString();
        } catch (e) {
            return url;
        }
    }

    getDraftStorageKey() {
        const id = this.originalFileId ? String(this.originalFileId) : 'new';
        return `soko-photo-editor:draft:${id}`;
    }

    maybeOfferDraftRestore() {
        if (!this.originalFileId) return;

        const fileId = String(this.originalFileId);
        if (this.draftPromptedForFileId === fileId) return;
        this.draftPromptedForFileId = fileId;

        const key = this.getDraftStorageKey();
        let draft = null;
        try {
            draft = JSON.parse(localStorage.getItem(key) || 'null');
        } catch (e) {
            draft = null;
        }

        if (!draft || !draft.state) return;
        if (this.historyIndex >= 0 && draft.state === this.history[this.historyIndex]) return;

        let when = '';
        try {
            const date = new Date(draft.updated_at || draft.updatedAt || Date.now());
            when = date.toLocaleString();
        } catch (e) {
            when = '';
        }

        const message = when
            ? `We found an autosaved draft from ${when}. Restore it?`
            : 'We found an autosaved draft. Restore it?';

        if (!confirm(message)) return;

        this.loadStateAsBaseline(draft.state);
        this.showToast('Draft restored', 'success');
    }

    loadStateAsBaseline(state) {
        this.canvas.loadFromJSON(state, () => {
            const objects = this.canvas.getObjects();
            this.currentImage = objects.find(obj => obj.isBackgroundImage);
            this.canvas.renderAll();
            this.history = [state];
            this.historyIndex = 0;
            this.savedHistoryIndex = 0;
            this.hasUnsavedChanges = false;
            this.updateHistoryButtons();
            this.updateLayersPanel();
        });
    }

    clearDraft(fileId = null) {
        const key = fileId ? `soko-photo-editor:draft:${String(fileId)}` : this.getDraftStorageKey();
        try {
            localStorage.removeItem(key);
        } catch (e) {
            // noop
        }
    }

    markAsSaved() {
        this.savedHistoryIndex = this.historyIndex;
        this.hasUnsavedChanges = false;
    }
    
    // ============================================
    // TOOL SELECTION
    // ============================================
    selectTool(toolName) {
        // Clear previous tool state
        this.exitCurrentTool();
        
        // Update UI
        document.querySelectorAll('.sidebar-tool').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tool === toolName);
        });
        
        this.currentTool = toolName;
        
        // Load tool panel
        this.loadToolPanel(toolName);
        
        // Apply tool-specific settings
        switch (toolName) {
            case 'select':
                this.canvas.isDrawingMode = false;
                this.canvas.selection = true;
                break;
            case 'crop':
                this.startCrop();
                break;
            case 'draw':
                this.startDrawing();
                break;
            default:
                this.canvas.isDrawingMode = false;
        }
    }
    
    exitCurrentTool() {
        if (this.isCropping) {
            this.cancelCrop();
        }
        if (this.canvas) {
            this.canvas.isDrawingMode = false;
        }
    }
    
    loadToolPanel(toolName) {
        const panel = document.getElementById('properties-panel');
        const template = document.getElementById(`template-${toolName}-panel`);
        
        if (template) {
            panel.innerHTML = '';
            panel.appendChild(template.content.cloneNode(true));
            
            // Reinitialize icons
            safeCreateIcons();
            
            // Setup tool-specific event listeners
            this.setupToolPanelEvents(toolName);
        } else {
            panel.innerHTML = `
                <div class="panel-placeholder">
                    <i data-lucide="settings-2"></i>
                    <p>Select a tool to see options</p>
                </div>
            `;
            safeCreateIcons();
        }
    }
    
    setupToolPanelEvents(toolName) {
        switch (toolName) {
            case 'resize':
                this.setupResizePanel();
                break;
            case 'crop':
                this.setupCropPanel();
                break;
            case 'rotate':
                this.setupRotatePanel();
                break;
            case 'adjust':
                this.setupAdjustPanel();
                break;
            case 'filters':
                this.setupFiltersPanel();
                break;
            case 'background':
                this.setupBackgroundPanel();
                break;
            case 'text':
                this.setupTextPanel();
                break;
            case 'draw':
                this.setupDrawPanel();
                break;
            case 'shapes':
                this.setupShapesPanel();
                break;
            case 'layers':
                this.setupLayersPanel();
                break;
            case 'brand':
                this.setupBrandPanel();
                break;
            case 'history':
                this.setupHistoryPanel();
                break;
        }
    }
    
    // ============================================
    // RESIZE TOOL (ENTERPRISE)
    // ============================================
    setupResizePanel() {
        // Get current image dimensions
        if (this.currentImage) {
            const width = Math.round(this.currentImage.width * this.currentImage.scaleX);
            const height = Math.round(this.currentImage.height * this.currentImage.scaleY);
            document.getElementById('resize-width').value = width;
            document.getElementById('resize-height').value = height;
            this.resizeAspectRatio = width / height;
        }
        
        this.lockAspectRatio = true;
        
        // Soko preset buttons
        document.querySelectorAll('.preset-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                document.getElementById('resize-width').value = btn.dataset.width;
                document.getElementById('resize-height').value = btn.dataset.height;
            });
        });
        
        // Link dimensions button
        const linkBtn = document.getElementById('btn-link-dimensions');
        linkBtn?.addEventListener('click', () => {
            this.lockAspectRatio = !this.lockAspectRatio;
            linkBtn.classList.toggle('active', this.lockAspectRatio);
            const icon = linkBtn.querySelector('i');
            if (icon) {
                icon.setAttribute('data-lucide', this.lockAspectRatio ? 'lock' : 'unlock');
                safeCreateIcons();
            }
        });
        
        // Width/Height inputs with aspect ratio lock
        const widthInput = document.getElementById('resize-width');
        const heightInput = document.getElementById('resize-height');
        
        widthInput?.addEventListener('input', () => {
            if (this.lockAspectRatio && this.resizeAspectRatio) {
                heightInput.value = Math.round(widthInput.value / this.resizeAspectRatio);
            }
        });
        
        heightInput?.addEventListener('input', () => {
            if (this.lockAspectRatio && this.resizeAspectRatio) {
                widthInput.value = Math.round(heightInput.value * this.resizeAspectRatio);
            }
        });
        
        // Aspect ratio buttons
        document.querySelectorAll('.aspect-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.aspect-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.startCropWithRatio(btn.dataset.ratio);
            });
        });
        
        // Apply/Cancel resize
        document.getElementById('btn-apply-resize')?.addEventListener('click', () => this.applyResize());
        document.getElementById('btn-cancel-resize')?.addEventListener('click', () => this.cancelResize());
        
        safeCreateIcons();
    }
    
    startCropWithRatio(ratio) {
        if (!this.currentImage) return;
        
        this.isCropping = true;
        this.isResizing = true;
        
        // Remove existing crop rect
        if (this.cropRect) {
            this.canvas.remove(this.cropRect);
        }
        
        const imgBounds = this.currentImage.getBoundingRect();
        let cropWidth = imgBounds.width - 40;
        let cropHeight = imgBounds.height - 40;
        
        if (ratio !== 'free') {
            const [w, h] = ratio.split(':').map(Number);
            const aspectRatio = w / h;
            
            if (cropWidth / cropHeight > aspectRatio) {
                cropWidth = cropHeight * aspectRatio;
            } else {
                cropHeight = cropWidth / aspectRatio;
            }
        }
        
        this.cropRect = new fabric.Rect({
            left: imgBounds.left + (imgBounds.width - cropWidth) / 2,
            top: imgBounds.top + (imgBounds.height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight,
            fill: 'rgba(0,0,0,0)',
            stroke: '#8b5cf6',
            strokeWidth: 2,
            strokeDashArray: [5, 5],
            cornerColor: '#8b5cf6',
            cornerSize: 10,
            transparentCorners: false,
            hasRotatingPoint: false,
            name: 'Crop Selection',
            isCropRect: true
        });
        
        this.canvas.add(this.cropRect);
        this.canvas.setActiveObject(this.cropRect);
        this.canvas.renderAll();
    }
    
    applyResize() {
        if (!this.currentImage) return;
        
        const newWidth = parseInt(document.getElementById('resize-width').value);
        const newHeight = parseInt(document.getElementById('resize-height').value);
        
        if (!newWidth || !newHeight) {
            this.showToast('Please enter valid dimensions', 'error');
            return;
        }
        
        this.showLoading();
        
        // If there's a crop rect, apply crop first, then resize
        if (this.cropRect) {
            this.applyCropAndResize(newWidth, newHeight);
        } else {
            // Just resize the image
            this.resizeImage(newWidth, newHeight);
        }
    }
    
    resizeImage(newWidth, newHeight) {
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = newWidth;
        tempCanvas.height = newHeight;
        const ctx = tempCanvas.getContext('2d');
        
        ctx.drawImage(this.currentImage._element, 0, 0, newWidth, newHeight);
        
        fabric.Image.fromURL(tempCanvas.toDataURL(), (resizedImg) => {
            const canvasArea = document.querySelector('.canvas-area');
            const maxWidth = canvasArea.clientWidth - 80;
            const maxHeight = canvasArea.clientHeight - 80;
            
            let scale = 1;
            if (resizedImg.width > maxWidth || resizedImg.height > maxHeight) {
                scale = Math.min(maxWidth / resizedImg.width, maxHeight / resizedImg.height);
            }
            
            this.canvas.setWidth(resizedImg.width * scale);
            this.canvas.setHeight(resizedImg.height * scale);
            
            this.canvas.remove(this.currentImage);
            if (this.cropRect) this.canvas.remove(this.cropRect);
            
            resizedImg.scale(scale);
            resizedImg.set({
                left: 0,
                top: 0,
                selectable: false,
                evented: false,
                name: 'Background Image',
                isBackgroundImage: true
            });
            
            this.canvas.add(resizedImg);
            this.canvas.sendToBack(resizedImg);
            this.currentImage = resizedImg;
            this.originalImage = resizedImg;
            
            this.isCropping = false;
            this.isResizing = false;
            this.cropRect = null;
            
            this.saveState();
            this.hideLoading();
            this.showToast(`Resized to ${newWidth}×${newHeight}`, 'success');
            this.selectTool('select');
        });
    }
    
    cancelResize() {
        if (this.cropRect) {
            this.canvas.remove(this.cropRect);
            this.cropRect = null;
        }
        this.isCropping = false;
        this.isResizing = false;
        this.canvas.renderAll();
    }
    
    // ============================================
    // CROP TOOL
    // ============================================
    setupCropPanel() {
        // Aspect ratio buttons
        document.querySelectorAll('.aspect-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.aspect-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.updateCropAspectRatio(btn.dataset.ratio);
            });
        });
        
        // Apply/Cancel crop
        document.getElementById('btn-apply-crop')?.addEventListener('click', () => this.applyCrop());
        document.getElementById('btn-cancel-crop')?.addEventListener('click', () => this.cancelCrop());
    }
    
    startCrop() {
        if (!this.currentImage) return;
        
        this.isCropping = true;
        
        // Create crop overlay
        const imgBounds = this.currentImage.getBoundingRect();
        
        this.cropRect = new fabric.Rect({
            left: imgBounds.left + 20,
            top: imgBounds.top + 20,
            width: imgBounds.width - 40,
            height: imgBounds.height - 40,
            fill: 'rgba(0,0,0,0)',
            stroke: '#8b5cf6',
            strokeWidth: 2,
            strokeDashArray: [5, 5],
            cornerColor: '#8b5cf6',
            cornerSize: 10,
            transparentCorners: false,
            hasRotatingPoint: false,
            name: 'Crop Selection',
            isCropRect: true
        });
        
        this.canvas.add(this.cropRect);
        this.canvas.setActiveObject(this.cropRect);
        this.canvas.renderAll();
    }
    
    updateCropAspectRatio(ratio) {
        if (!this.cropRect) return;
        
        if (ratio === 'free') {
            this.cropRect.setControlsVisibility({
                mt: true, mb: true, ml: true, mr: true
            });
        } else {
            const [w, h] = ratio.split(':').map(Number);
            const aspectRatio = w / h;
            
            const currentWidth = this.cropRect.width;
            const newHeight = currentWidth / aspectRatio;
            
            this.cropRect.set({ height: newHeight });
            this.cropRect.setControlsVisibility({
                mt: false, mb: false, ml: false, mr: false
            });
        }
        
        this.canvas.renderAll();
    }
    
    applyCrop() {
        if (!this.cropRect || !this.currentImage) return;
        
        this.showLoading();
        
        // Get crop dimensions in image coordinates
        const cropBounds = this.cropRect.getBoundingRect();
        const imgBounds = this.currentImage.getBoundingRect();
        const scale = this.currentImage.scaleX;
        
        const cropX = (cropBounds.left - imgBounds.left) / scale;
        const cropY = (cropBounds.top - imgBounds.top) / scale;
        const cropWidth = cropBounds.width / scale;
        const cropHeight = cropBounds.height / scale;
        
        // Create a temporary canvas to crop the image
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = cropWidth;
        tempCanvas.height = cropHeight;
        const ctx = tempCanvas.getContext('2d');
        
        // Draw cropped portion
        const imgElement = this.currentImage._element;
        ctx.drawImage(imgElement, cropX, cropY, cropWidth, cropHeight, 0, 0, cropWidth, cropHeight);
        
        // Load cropped image
        fabric.Image.fromURL(tempCanvas.toDataURL(), (croppedImg) => {
            // Calculate new scale
            const canvasArea = document.querySelector('.canvas-area');
            const maxWidth = canvasArea.clientWidth - 80;
            const maxHeight = canvasArea.clientHeight - 80;
            
            let newScale = 1;
            if (croppedImg.width > maxWidth || croppedImg.height > maxHeight) {
                newScale = Math.min(maxWidth / croppedImg.width, maxHeight / croppedImg.height);
            }
            
            // Update canvas size
            this.canvas.setWidth(croppedImg.width * newScale);
            this.canvas.setHeight(croppedImg.height * newScale);
            
            // Replace image
            this.canvas.remove(this.currentImage);
            this.canvas.remove(this.cropRect);
            
            croppedImg.scale(newScale);
            croppedImg.set({
                left: 0,
                top: 0,
                selectable: false,
                evented: false,
                name: 'Background Image',
                isBackgroundImage: true
            });
            
            this.canvas.add(croppedImg);
            this.canvas.sendToBack(croppedImg);
            this.currentImage = croppedImg;
            this.originalImage = croppedImg;
            
            this.isCropping = false;
            this.cropRect = null;
            
            this.saveState();
            this.hideLoading();
            this.selectTool('select');
        });
    }
    
    cancelCrop() {
        if (this.cropRect) {
            this.canvas.remove(this.cropRect);
            this.cropRect = null;
        }
        this.isCropping = false;
        this.canvas.renderAll();
    }
    
    // ============================================
    // ROTATE TOOL
    // ============================================
    setupRotatePanel() {
        const slider = document.getElementById('rotation-slider');
        const valueDisplay = document.getElementById('rotation-value');
        
        slider?.addEventListener('input', (e) => {
            const angle = parseInt(e.target.value);
            valueDisplay.textContent = angle + '°';
            this.rotateImage(angle);
        });
        
        // Quick rotate buttons
        document.querySelectorAll('[data-rotate]').forEach(btn => {
            btn.addEventListener('click', () => {
                const angle = parseInt(btn.dataset.rotate);
                this.quickRotate(angle);
            });
        });
        
        // Flip buttons
        document.querySelectorAll('[data-flip]').forEach(btn => {
            btn.addEventListener('click', () => {
                this.flipImage(btn.dataset.flip);
            });
        });
    }
    
    rotateImage(angle) {
        if (!this.currentImage) return;
        this.currentImage.set('angle', angle);
        this.canvas.renderAll();
    }
    
    quickRotate(angle) {
        if (!this.currentImage) return;
        const currentAngle = this.currentImage.angle || 0;
        const newAngle = (currentAngle + angle) % 360;
        this.currentImage.set('angle', newAngle);
        
        const slider = document.getElementById('rotation-slider');
        const valueDisplay = document.getElementById('rotation-value');
        if (slider) slider.value = newAngle;
        if (valueDisplay) valueDisplay.textContent = newAngle + '°';
        
        this.canvas.renderAll();
        this.saveState();
    }
    
    flipImage(direction) {
        if (!this.currentImage) return;
        
        if (direction === 'horizontal') {
            this.currentImage.set('flipX', !this.currentImage.flipX);
        } else {
            this.currentImage.set('flipY', !this.currentImage.flipY);
        }
        
        this.canvas.renderAll();
        this.saveState();
    }
    
    // ============================================
    // ADJUSTMENTS
    // ============================================
    setupAdjustPanel() {
        document.querySelectorAll('.adjustment-slider').forEach(slider => {
            const type = slider.dataset.adjust;
            const valueDisplay = document.getElementById(`${type}-value`);
            
            // Set initial value
            slider.value = this.adjustments[type];
            if (valueDisplay) valueDisplay.textContent = this.adjustments[type];
            
            slider.addEventListener('input', (e) => {
                const value = parseInt(e.target.value);
                this.adjustments[type] = value;
                if (valueDisplay) valueDisplay.textContent = value;
                this.applyAdjustments();
            });
        });
        
        document.getElementById('btn-reset-adjustments')?.addEventListener('click', () => {
            this.resetAdjustments();
        });
    }
    
    applyAdjustments() {
        if (!this.currentImage) return;
        
        const filters = [];
        
        // Brightness
        if (this.adjustments.brightness !== 0) {
            filters.push(new fabric.Image.filters.Brightness({
                brightness: this.adjustments.brightness / 100
            }));
        }
        
        // Contrast
        if (this.adjustments.contrast !== 0) {
            filters.push(new fabric.Image.filters.Contrast({
                contrast: this.adjustments.contrast / 100
            }));
        }
        
        // Saturation
        if (this.adjustments.saturation !== 0) {
            filters.push(new fabric.Image.filters.Saturation({
                saturation: this.adjustments.saturation / 100
            }));
        }
        
        // Hue rotation
        if (this.adjustments.hue !== 0) {
            filters.push(new fabric.Image.filters.HueRotation({
                rotation: this.adjustments.hue / 180
            }));
        }
        
        // Blur
        if (this.adjustments.blur > 0) {
            filters.push(new fabric.Image.filters.Blur({
                blur: this.adjustments.blur / 100
            }));
        }
        
        // Noise
        if (this.adjustments.noise > 0) {
            filters.push(new fabric.Image.filters.Noise({
                noise: this.adjustments.noise * 5
            }));
        }
        
        this.currentImage.filters = filters;
        this.currentImage.applyFilters();
        this.canvas.renderAll();
    }
    
    resetAdjustments() {
        this.adjustments = {
            brightness: 0,
            contrast: 0,
            saturation: 0,
            hue: 0,
            blur: 0,
            noise: 0
        };
        
        // Reset UI
        document.querySelectorAll('.adjustment-slider').forEach(slider => {
            slider.value = 0;
            const type = slider.dataset.adjust;
            const valueDisplay = document.getElementById(`${type}-value`);
            if (valueDisplay) valueDisplay.textContent = '0';
        });
        
        this.applyAdjustments();
        this.saveState();
    }
    
    // ============================================
    // FILTERS
    // ============================================
    setupFiltersPanel() {
        const grid = document.getElementById('filters-grid');
        if (!grid) return;
        
        grid.innerHTML = '';
        
        FILTER_PRESETS.forEach(preset => {
            const btn = document.createElement('button');
            btn.className = `filter-btn ${preset.name === this.currentFilter ? 'active' : ''}`;
            btn.innerHTML = `<span>${preset.name}</span>`;
            btn.addEventListener('click', () => this.applyFilter(preset));
            grid.appendChild(btn);
        });
    }
    
    applyFilter(preset) {
        if (!this.currentImage) return;
        
        // Update UI
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.textContent === preset.name);
        });
        
        this.currentFilter = preset.name;
        
        // Apply filters
        const filters = preset.filters.map(f => {
            switch (f.type) {
                case 'Grayscale': return new fabric.Image.filters.Grayscale();
                case 'Sepia': return new fabric.Image.filters.Sepia();
                case 'Invert': return new fabric.Image.filters.Invert();
                case 'Brightness': return new fabric.Image.filters.Brightness({ brightness: f.brightness });
                case 'Contrast': return new fabric.Image.filters.Contrast({ contrast: f.contrast });
                case 'Saturation': return new fabric.Image.filters.Saturation({ saturation: f.saturation });
                case 'HueRotation': return new fabric.Image.filters.HueRotation({ rotation: f.rotation });
                case 'Noise': return new fabric.Image.filters.Noise({ noise: f.noise });
                case 'Blur': return new fabric.Image.filters.Blur({ blur: f.blur });
                case 'Convolute': return new fabric.Image.filters.Convolute({ matrix: f.matrix });
                default: return null;
            }
        }).filter(Boolean);
        
        this.currentImage.filters = filters;
        this.currentImage.applyFilters();
        this.canvas.renderAll();
        this.saveState();
    }
    
    // ============================================
    // BACKGROUND REMOVAL
    // ============================================
    setupBackgroundPanel() {
        document.getElementById('btn-remove-bg')?.addEventListener('click', () => {
            this.removeBackground();
        });

        const toleranceInput = document.getElementById('bg-tolerance');
        const toleranceValue = document.getElementById('bg-tolerance-value');
        const featherInput = document.getElementById('bg-feather');
        const featherValue = document.getElementById('bg-feather-value');

        const persist = () => {
            try {
                localStorage.setItem('soko-photo-editor:bg-settings', JSON.stringify(this.bgRemoveSettings));
            } catch (e) {
                // noop
            }
        };

        if (toleranceInput) {
            toleranceInput.value = String(this.bgRemoveSettings.tolerance ?? 32);
            if (toleranceValue) toleranceValue.textContent = toleranceInput.value;
            toleranceInput.addEventListener('input', (e) => {
                const value = clampInt(Number(e.target.value) || 32, 5, 90);
                this.bgRemoveSettings.tolerance = value;
                if (toleranceValue) toleranceValue.textContent = String(value);
                persist();
            });
        }

        if (featherInput) {
            featherInput.value = String(this.bgRemoveSettings.feather ?? 2);
            if (featherValue) featherValue.textContent = featherInput.value;
            featherInput.addEventListener('input', (e) => {
                const value = clampInt(Number(e.target.value) || 2, 0, 12);
                this.bgRemoveSettings.feather = value;
                if (featherValue) featherValue.textContent = String(value);
                persist();
            });
        }
        
        // Background color buttons
        document.querySelectorAll('.bg-color-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                this.setBackgroundColor(btn.dataset.color);
            });
        });
        
        // Custom color
        document.getElementById('bg-custom-color')?.addEventListener('change', (e) => {
            this.setBackgroundColor(e.target.value);
        });
    }
    
    async removeBackground() {
        if (!this.currentImage) return;
        
        this.showLoading();
        
        try {
            const tolerance = clampInt(Number(this.bgRemoveSettings?.tolerance) || 32, 5, 90);
            const feather = clampInt(Number(this.bgRemoveSettings?.feather) || 2, 0, 12);

            const dataUrl = this.currentImage.toDataURL({ format: 'png', quality: 1 });
            const img = await new Promise((resolve, reject) => {
                const image = new Image();
                image.onload = () => resolve(image);
                image.onerror = () => reject(new Error('Failed to load image for processing'));
                image.src = dataUrl;
            });

            const w = img.naturalWidth || img.width;
            const h = img.naturalHeight || img.height;
            if (!w || !h) {
                throw new Error('Invalid image size');
            }

            const offscreen = document.createElement('canvas');
            offscreen.width = w;
            offscreen.height = h;
            const ctx = offscreen.getContext('2d', { willReadFrequently: true });
            if (!ctx) {
                throw new Error('Canvas not supported');
            }
            ctx.drawImage(img, 0, 0);
            const imageData = ctx.getImageData(0, 0, w, h);
            const data = imageData.data;

            const region = Math.max(10, Math.min(24, Math.round(Math.min(w, h) * 0.06)));
            const corners = [
                averageRegionColor(data, w, h, 0, 0, region),
                averageRegionColor(data, w, h, w - region, 0, region),
                averageRegionColor(data, w, h, 0, h - region, region),
                averageRegionColor(data, w, h, w - region, h - region, region),
            ];
            const bgColor = pickDominantCornerColor(corners);

            const bgMask = buildBackgroundMask(imageData, w, h, bgColor, tolerance);

            const alpha = new Uint8ClampedArray(w * h);
            for (let p = 0; p < w * h; p++) {
                const a = data[p * 4 + 3];
                if (bgMask[p]) {
                    data[p * 4 + 3] = 0;
                    alpha[p] = 0;
                } else {
                    alpha[p] = a;
                }
            }

            if (feather > 0) {
                const blurred = blurAlphaChannel(alpha, w, h, feather);
                for (let p = 0; p < w * h; p++) {
                    if (!bgMask[p]) {
                        data[p * 4 + 3] = blurred[p];
                    }
                }
            }

            ctx.putImageData(imageData, 0, 0);

            const blob = await new Promise((resolve) => offscreen.toBlob(resolve, 'image/png'));
            if (!blob) {
                throw new Error('Failed to generate output image');
            }

            const resultUrl = URL.createObjectURL(blob);
            fabric.Image.fromURL(
                resultUrl,
                (newImg) => {
                    URL.revokeObjectURL(resultUrl);

                    const scale = this.currentImage.scaleX;
                    this.canvas.remove(this.currentImage);

                    newImg.scale(scale);
                    newImg.set({
                        left: 0,
                        top: 0,
                        selectable: false,
                        evented: false,
                        name: 'Background Image',
                        isBackgroundImage: true,
                    });

                    this.canvas.add(newImg);
                    this.canvas.sendToBack(newImg);
                    this.currentImage = newImg;

                    this.saveState();
                    this.hideLoading();
                    this.showToast('Background removed', 'success');
                },
                { crossOrigin: 'anonymous' }
            );
        } catch (error) {
            console.error('Background removal error:', error);
            this.hideLoading();
            this.showToast('Background removal failed. Try adjusting tolerance.', 'error');
        }
    }
    
    setBackgroundColor(color) {
        if (color === 'transparent') {
            this.canvas.backgroundColor = null;
        } else {
            this.canvas.backgroundColor = color;
        }
        this.canvas.renderAll();
    }

    // ============================================
    // BRAND KIT
    // ============================================
    async fetchBrandKit() {
        const baseUrl = window.location.origin;
        const response = await fetch(`${baseUrl}/photo-editor/brand-kit`, {
            credentials: 'include',
            headers: { 'Accept': 'application/json' },
        });

        const contentType = response.headers.get('content-type') || '';
        if (!response.ok || !contentType.includes('application/json')) {
            throw new Error('Failed to load brand kit');
        }

        return await response.json();
    }

    async setupBrandPanel() {
        const loadingEl = document.getElementById('brand-kit-loading');
        const errorEl = document.getElementById('brand-kit-error');
        const contentEl = document.getElementById('brand-kit-content');
        const logoImgEl = document.getElementById('brand-logo-img');
        const logoPlaceholderEl = document.getElementById('brand-logo-placeholder');
        const addLogoBtn = document.getElementById('btn-add-brand-logo');
        const colorsEl = document.getElementById('brand-colors');
        const watermarkInput = document.getElementById('brand-watermark-text');
        const addWatermarkBtn = document.getElementById('btn-add-watermark');

        if (!loadingEl || !contentEl) return;

        loadingEl.classList.remove('hidden');
        errorEl?.classList.add('hidden');
        contentEl.classList.add('hidden');

        try {
            const kit = await this.fetchBrandKit();
            const logoUrl = kit?.logo_url || null;
            const colors = Array.isArray(kit?.colors) ? kit.colors : [];
            const watermarkText = kit?.watermark_text || kit?.shop_name || '';

            if (watermarkInput && watermarkText) watermarkInput.value = watermarkText;

            if (logoImgEl && logoPlaceholderEl) {
                if (logoUrl) {
                    logoImgEl.src = logoUrl;
                    logoImgEl.classList.remove('hidden');
                    logoPlaceholderEl.classList.add('hidden');
                } else {
                    logoImgEl.classList.add('hidden');
                    logoPlaceholderEl.classList.remove('hidden');
                }
            }

            if (addLogoBtn) {
                addLogoBtn.disabled = !logoUrl;
                addLogoBtn.onclick = () => {
                    if (!logoUrl) return;
                    this.addBrandLogo(logoUrl);
                };
            }

            if (colorsEl) {
                colorsEl.innerHTML = '';
                colors.forEach((color) => {
                    const btn = document.createElement('button');
                    btn.type = 'button';
                    btn.className = 'bg-color-btn';
                    btn.dataset.color = color;
                    btn.title = color;
                    btn.style.background = color;
                    btn.addEventListener('click', () => this.applyBrandColor(color));
                    colorsEl.appendChild(btn);
                });
            }

            if (addWatermarkBtn) {
                addWatermarkBtn.onclick = () => {
                    const value = (watermarkInput?.value || watermarkText || '').trim();
                    if (!value) {
                        this.showToast('Enter watermark text', 'error');
                        return;
                    }
                    this.addWatermark(value);
                };
            }

            loadingEl.classList.add('hidden');
            contentEl.classList.remove('hidden');
            safeCreateIcons();
        } catch (error) {
            console.error('Brand kit error:', error);
            loadingEl.classList.add('hidden');
            errorEl?.classList.remove('hidden');
            contentEl.classList.add('hidden');
            safeCreateIcons();
        }
    }

    applyBrandColor(color) {
        if (!this.canvas) return;

        const active = this.canvas.getActiveObject();
        if (active && typeof active.set === 'function') {
            const type = String(active.type || '').toLowerCase();
            if (type.includes('text') || type.includes('textbox')) {
                active.set('fill', color);
                this.canvas.renderAll();
                this.saveState();
                return;
            }

            if (Object.prototype.hasOwnProperty.call(active, 'fill')) {
                active.set('fill', color);
                this.canvas.renderAll();
                this.saveState();
                return;
            }
        }

        this.setBackgroundColor(color);
        this.saveState();
    }

    addBrandLogo(logoUrl) {
        if (!this.canvas) return;

        this.showLoading();
        fabric.Image.fromURL(
            logoUrl,
            (img) => {
                try {
                    const maxWidth = Math.min(180, this.canvas.getWidth() * 0.4);
                    const scale = img.width ? maxWidth / img.width : 1;
                    img.scale(scale);
                    img.set({
                        left: 20,
                        top: this.canvas.getHeight() - img.getScaledHeight() - 20,
                        selectable: true,
                        evented: true,
                        name: 'Brand Logo',
                    });
                    this.canvas.add(img);
                    this.canvas.bringToFront(img);
                    this.canvas.setActiveObject(img);
                    this.canvas.renderAll();
                    this.saveState();
                    this.showToast('Logo added', 'success');
                } finally {
                    this.hideLoading();
                }
            },
            { crossOrigin: 'anonymous' }
        );
    }

    addWatermark(text) {
        if (!this.canvas) return;

        const watermark = new fabric.Textbox(text, {
            left: 0,
            top: 0,
            fontFamily: this.textSettings?.fontFamily || 'system-ui',
            fontSize: 28,
            fill: '#0f172a',
            opacity: 0.25,
            selectable: true,
            evented: true,
            name: 'Watermark',
        });

        watermark.set({
            left: Math.max(16, this.canvas.getWidth() - watermark.width - 20),
            top: Math.max(16, this.canvas.getHeight() - watermark.height - 20),
        });

        this.canvas.add(watermark);
        this.canvas.bringToFront(watermark);
        this.canvas.setActiveObject(watermark);
        this.canvas.renderAll();
        this.saveState();
        this.showToast('Watermark added', 'success');
    }

    // ============================================
    // HISTORY
    // ============================================
    async fetchHistory(fileId) {
        const baseUrl = window.location.origin;
        const response = await fetch(`${baseUrl}/photo-editor/history/${fileId}`, {
            credentials: 'include',
            headers: { 'Accept': 'application/json' },
        });

        const contentType = response.headers.get('content-type') || '';
        if (!response.ok || !contentType.includes('application/json')) {
            throw new Error('Failed to load history');
        }

        return await response.json();
    }

    setupHistoryPanel() {
        const noteEl = document.getElementById('history-note');
        const listEl = document.getElementById('history-list');
        if (!listEl) return;

        if (!this.originalFileId) {
            if (noteEl) {
                noteEl.textContent = 'Open an uploaded image to see versions.';
                noteEl.classList.remove('hidden');
            }
            listEl.innerHTML = '';
            return;
        }

        if (noteEl) {
            noteEl.textContent = 'Loading…';
            noteEl.classList.remove('hidden');
        }
        listEl.innerHTML = '';

        this.fetchHistory(this.originalFileId)
            .then((payload) => {
                const entries = Array.isArray(payload?.data) ? payload.data : [];
                if (!entries.length) {
                    if (noteEl) {
                        noteEl.textContent = 'No versions yet.';
                        noteEl.classList.remove('hidden');
                    }
                    return;
                }

                if (noteEl) noteEl.classList.add('hidden');

                entries.forEach((entry) => {
                    const action = entry?.action === 'replace' ? 'Replaced original' : 'Saved as new';
                    const when = entry?.created_at ? new Date(entry.created_at).toLocaleString() : '';

                    const item = document.createElement('div');
                    item.className = 'history-item';
                    item.innerHTML = `
                        <div class="history-item-header">
                            <div>
                                <div class="history-item-title">${this.escapeHtml(action)}</div>
                                <div class="history-item-meta">${this.escapeHtml(when)}</div>
                            </div>
                        </div>
                        <div class="history-files"></div>
                    `;

                    const filesContainer = item.querySelector('.history-files');
                    const candidates = [];

                    if (entry?.action === 'replace' && entry?.backup_file?.id) {
                        candidates.push({ label: 'Backup', file: entry.backup_file, canRestore: true });
                    }
                    if (entry?.action === 'save_new' && entry?.new_file?.id) {
                        candidates.push({ label: 'Saved Copy', file: entry.new_file, canRestore: true });
                    }

                    candidates.forEach(({ label, file, canRestore }) => {
                        const fileRow = document.createElement('div');
                        fileRow.className = 'history-file';
                        fileRow.innerHTML = `
                            <div class="history-thumb">
                                <img src="${this.escapeHtml(file.url || '')}" alt="${this.escapeHtml(file.file_original_name || label)}">
                            </div>
                            <div class="history-file-info">
                                <div class="history-file-name">${this.escapeHtml(file.file_original_name || label)}</div>
                                <div class="history-file-sub">${this.escapeHtml(label)}</div>
                            </div>
                            <div class="history-actions">
                                <button type="button" class="history-action-btn" data-action="open">
                                    <i data-lucide="eye"></i>
                                    Open
                                </button>
                                ${
                                    canRestore
                                        ? `<button type="button" class="history-action-btn history-action-danger" data-action="restore">
                                            <i data-lucide="rotate-ccw"></i>
                                            Restore
                                        </button>`
                                        : ''
                                }
                            </div>
                        `;

                        fileRow.querySelector('[data-action="open"]')?.addEventListener('click', () => {
                            if (file.url) {
                                this.loadImageFromUrl(file.url);
                                this.showToast('Version loaded', 'success');
                            }
                        });

                        fileRow.querySelector('[data-action="restore"]')?.addEventListener('click', () => {
                            this.restoreUploadToOriginal(file.id);
                        });

                        filesContainer?.appendChild(fileRow);
                    });

                    listEl.appendChild(item);
                });

                safeCreateIcons();
            })
            .catch((error) => {
                console.error('History error:', error);
                if (noteEl) {
                    noteEl.textContent = 'Unable to load history.';
                    noteEl.classList.remove('hidden');
                }
                listEl.innerHTML = '';
            });
    }

    async restoreUploadToOriginal(sourceUploadId) {
        if (!this.originalFileId || !sourceUploadId) return;

        const confirmed = confirm('Restore this version and replace the current original?');
        if (!confirmed) return;

        this.showLoading();

        try {
            const baseUrl = window.location.origin;

            const infoResponse = await fetch(`${baseUrl}/photo-editor/file-info/${sourceUploadId}`, {
                credentials: 'include',
                headers: { 'Accept': 'application/json' },
            });
            if (!infoResponse.ok) throw new Error('Failed to fetch version info');
            const info = await infoResponse.json();

            const blobResponse = await fetch(info.url, { credentials: 'include' });
            if (!blobResponse.ok) throw new Error('Failed to download version');
            const blob = await blobResponse.blob();

            const extension = (info.extension || 'png').toLowerCase();
            const filename = `${(info.file_original_name || 'restored').replace(/[\\n\\r\\t]/g, ' ').trim()}.${extension}`;

            const formData = new FormData();
            formData.append('aiz_file', blob, filename);
            formData.append('replace_file_id', this.originalFileId);
            formData.append('keep_previous', '1');
            formData.append('source', 'photo-editor-restore');

            const csrfToken = await this.getCsrfToken(baseUrl);
            const uploadResponse = await fetch(`${baseUrl}/aiz-uploader/upload`, {
                method: 'POST',
                body: formData,
                headers: { 'X-CSRF-TOKEN': csrfToken },
                credentials: 'include',
            });

            if (!uploadResponse.ok) {
                throw new Error('Restore failed');
            }

            const result = await uploadResponse.json();

            this.hideLoading();
            this.showToast('Restored', 'success');

            this.clearDraft(this.originalFileId);
            this.markAsSaved();

            if (result?.url) {
                this.loadImageFromUrl(result.url);
            } else {
                this.loadImageFromFileId(this.originalFileId);
            }

            this.postSavedMessage({
                action: 'replace',
                id: this.originalFileId,
                url: result?.url,
                original_file_id: this.originalFileId,
            });

            this.setupHistoryPanel();
        } catch (error) {
            console.error('Restore error:', error);
            this.csrfToken = null;
            this.hideLoading();
            this.showToast('Restore failed', 'error');
        }
    }
    
    // ============================================
    // TEXT TOOL
    // ============================================
    setupTextPanel() {
        document.getElementById('btn-add-text')?.addEventListener('click', () => {
            this.addText();
        });
        
        // Font family
        document.getElementById('font-family')?.addEventListener('change', (e) => {
            this.textSettings.fontFamily = e.target.value;
            this.updateSelectedText();
        });
        
        // Font size
        document.getElementById('font-size')?.addEventListener('input', (e) => {
            this.textSettings.fontSize = parseInt(e.target.value);
            document.getElementById('font-size-value').textContent = e.target.value + 'px';
            this.updateSelectedText();
        });
        
        // Style buttons
        document.getElementById('btn-bold')?.addEventListener('click', (e) => {
            e.currentTarget.classList.toggle('active');
            this.textSettings.bold = e.currentTarget.classList.contains('active');
            this.updateSelectedText();
        });
        
        document.getElementById('btn-italic')?.addEventListener('click', (e) => {
            e.currentTarget.classList.toggle('active');
            this.textSettings.italic = e.currentTarget.classList.contains('active');
            this.updateSelectedText();
        });
        
        document.getElementById('btn-underline')?.addEventListener('click', (e) => {
            e.currentTarget.classList.toggle('active');
            this.textSettings.underline = e.currentTarget.classList.contains('active');
            this.updateSelectedText();
        });
        
        // Text color
        document.getElementById('text-color')?.addEventListener('change', (e) => {
            this.textSettings.fill = e.target.value;
            this.updateSelectedText();
        });
    }
    
    addText() {
        const textContent = document.getElementById('text-content')?.value || 'Your Text';
        
        const text = new fabric.IText(textContent, {
            left: this.canvas.width / 2,
            top: this.canvas.height / 2,
            originX: 'center',
            originY: 'center',
            fontFamily: this.textSettings.fontFamily,
            fontSize: this.textSettings.fontSize,
            fill: this.textSettings.fill,
            fontWeight: this.textSettings.bold ? 'bold' : 'normal',
            fontStyle: this.textSettings.italic ? 'italic' : 'normal',
            underline: this.textSettings.underline,
            name: 'Text Layer'
        });
        
        this.canvas.add(text);
        this.canvas.setActiveObject(text);
        this.canvas.renderAll();
        this.saveState();
    }
    
    updateSelectedText() {
        const obj = this.canvas.getActiveObject();
        if (obj && obj.type === 'i-text') {
            obj.set({
                fontFamily: this.textSettings.fontFamily,
                fontSize: this.textSettings.fontSize,
                fill: this.textSettings.fill,
                fontWeight: this.textSettings.bold ? 'bold' : 'normal',
                fontStyle: this.textSettings.italic ? 'italic' : 'normal',
                underline: this.textSettings.underline
            });
            this.canvas.renderAll();
        }
    }
    
    // ============================================
    // DRAWING TOOL
    // ============================================
    setupDrawPanel() {
        // Brush type
        document.querySelectorAll('.draw-tool-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.draw-tool-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.brushSettings.type = btn.dataset.draw;
                this.updateBrush();
            });
        });
        
        // Brush size
        document.getElementById('brush-size')?.addEventListener('input', (e) => {
            this.brushSettings.size = parseInt(e.target.value);
            document.getElementById('brush-size-value').textContent = e.target.value + 'px';
            this.updateBrush();
        });
        
        // Brush opacity
        document.getElementById('brush-opacity')?.addEventListener('input', (e) => {
            this.brushSettings.opacity = parseInt(e.target.value);
            document.getElementById('brush-opacity-value').textContent = e.target.value + '%';
            this.updateBrush();
        });
        
        // Brush color
        document.getElementById('brush-color')?.addEventListener('change', (e) => {
            this.brushSettings.color = e.target.value;
            this.updateBrush();
        });
    }
    
    startDrawing() {
        this.canvas.isDrawingMode = true;
        this.updateBrush();
    }
    
    updateBrush() {
        if (!this.canvas.isDrawingMode) return;
        
        let brush;
        
        switch (this.brushSettings.type) {
            case 'pencil':
                brush = new fabric.PencilBrush(this.canvas);
                break;
            case 'spray':
                brush = new fabric.SprayBrush(this.canvas);
                brush.density = 20;
                break;
            case 'eraser':
                // Use white brush as eraser effect
                brush = new fabric.PencilBrush(this.canvas);
                brush.color = '#ffffff';
                this.canvas.freeDrawingBrush = brush;
                brush.width = this.brushSettings.size;
                return;
            default:
                brush = new fabric.PencilBrush(this.canvas);
        }
        
        brush.color = this.brushSettings.color;
        brush.width = this.brushSettings.size;
        
        // Convert opacity to hex
        const opacity = Math.round((this.brushSettings.opacity / 100) * 255);
        const opacityHex = opacity.toString(16).padStart(2, '0');
        brush.color = this.brushSettings.color + opacityHex;
        
        this.canvas.freeDrawingBrush = brush;
    }
    
    // ============================================
    // SHAPES TOOL
    // ============================================
    setupShapesPanel() {
        // Shape buttons
        document.querySelectorAll('.shape-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                this.addShape(btn.dataset.shape);
            });
        });
        
        // Fill color
        document.getElementById('shape-fill')?.addEventListener('change', (e) => {
            this.shapeSettings.fill = e.target.value;
            this.updateSelectedShape();
        });
        
        // Stroke color
        document.getElementById('shape-stroke')?.addEventListener('change', (e) => {
            this.shapeSettings.stroke = e.target.value;
            this.updateSelectedShape();
        });
        
        // Stroke width
        document.getElementById('stroke-width')?.addEventListener('input', (e) => {
            this.shapeSettings.strokeWidth = parseInt(e.target.value);
            document.getElementById('stroke-width-value').textContent = e.target.value + 'px';
            this.updateSelectedShape();
        });
    }
    
    addShape(shapeType) {
        let shape;
        const centerX = this.canvas.width / 2;
        const centerY = this.canvas.height / 2;
        const size = Math.min(this.canvas.width, this.canvas.height) * 0.2;
        
        switch (shapeType) {
            case 'rect':
                shape = new fabric.Rect({
                    width: size,
                    height: size * 0.7,
                    fill: this.shapeSettings.fill,
                    stroke: this.shapeSettings.stroke,
                    strokeWidth: this.shapeSettings.strokeWidth
                });
                break;
            case 'circle':
                shape = new fabric.Circle({
                    radius: size / 2,
                    fill: this.shapeSettings.fill,
                    stroke: this.shapeSettings.stroke,
                    strokeWidth: this.shapeSettings.strokeWidth
                });
                break;
            case 'triangle':
                shape = new fabric.Triangle({
                    width: size,
                    height: size,
                    fill: this.shapeSettings.fill,
                    stroke: this.shapeSettings.stroke,
                    strokeWidth: this.shapeSettings.strokeWidth
                });
                break;
            case 'line':
                shape = new fabric.Line([0, 0, size, 0], {
                    stroke: this.shapeSettings.stroke,
                    strokeWidth: this.shapeSettings.strokeWidth
                });
                break;
            case 'arrow':
                // Create arrow using path
                const arrowPath = `M 0 ${size/4} L ${size*0.6} ${size/4} L ${size*0.6} 0 L ${size} ${size/2} L ${size*0.6} ${size} L ${size*0.6} ${size*0.75} L 0 ${size*0.75} Z`;
                shape = new fabric.Path(arrowPath, {
                    fill: this.shapeSettings.fill,
                    stroke: this.shapeSettings.stroke,
                    strokeWidth: this.shapeSettings.strokeWidth
                });
                break;
            case 'star':
                shape = this.createStar(size/2, 5);
                break;
            default:
                return;
        }
        
        shape.set({
            left: centerX,
            top: centerY,
            originX: 'center',
            originY: 'center',
            name: `${shapeType.charAt(0).toUpperCase() + shapeType.slice(1)} Shape`
        });
        
        this.canvas.add(shape);
        this.canvas.setActiveObject(shape);
        this.canvas.renderAll();
        this.saveState();
    }
    
    createStar(radius, points) {
        const innerRadius = radius * 0.5;
        const step = Math.PI / points;
        
        let pathData = '';
        for (let i = 0; i < 2 * points; i++) {
            const r = i % 2 === 0 ? radius : innerRadius;
            const angle = i * step - Math.PI / 2;
            const x = Math.cos(angle) * r + radius;
            const y = Math.sin(angle) * r + radius;
            pathData += (i === 0 ? 'M' : 'L') + ` ${x} ${y} `;
        }
        pathData += 'Z';
        
        return new fabric.Path(pathData, {
            fill: this.shapeSettings.fill,
            stroke: this.shapeSettings.stroke,
            strokeWidth: this.shapeSettings.strokeWidth
        });
    }
    
    updateSelectedShape() {
        const obj = this.canvas.getActiveObject();
        if (obj && !obj.isBackgroundImage && obj.type !== 'i-text') {
            obj.set({
                fill: this.shapeSettings.fill,
                stroke: this.shapeSettings.stroke,
                strokeWidth: this.shapeSettings.strokeWidth
            });
            this.canvas.renderAll();
        }
    }
    
    // ============================================
    // LAYERS
    // ============================================
    setupLayersPanel() {
        document.getElementById('btn-layer-up')?.addEventListener('click', () => this.moveLayerUp());
        document.getElementById('btn-layer-down')?.addEventListener('click', () => this.moveLayerDown());
        document.getElementById('btn-layer-delete')?.addEventListener('click', () => this.deleteSelected());
        document.getElementById('btn-layer-duplicate')?.addEventListener('click', () => this.duplicateSelected());
        
        this.updateLayersPanel();
    }
    
    updateLayersPanel() {
        const list = document.getElementById('layers-list');
        if (!list) return;
        
        const objects = this.canvas.getObjects().slice().reverse();
        const activeObject = this.canvas.getActiveObject();
        
        list.innerHTML = objects.map((obj, index) => {
            const isActive = obj === activeObject;
            const name = obj.name || `Layer ${objects.length - index}`;
            const type = obj.type || 'object';
            
            return `
                <div class="layer-item ${isActive ? 'active' : ''}" data-index="${objects.length - 1 - index}">
                    <div class="layer-thumbnail">
                        <div style="width:100%;height:100%;background:#27272a;display:flex;align-items:center;justify-content:center;color:#71717a;">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="3" y="3" width="18" height="18" rx="2"/>
                            </svg>
                        </div>
                    </div>
                    <div class="layer-info">
                        <div class="layer-name">${name}</div>
                        <div class="layer-type">${type}</div>
                    </div>
                    <button class="layer-visibility ${obj.visible === false ? 'hidden' : ''}" data-index="${objects.length - 1 - index}">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            ${obj.visible !== false 
                                ? '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>'
                                : '<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>'
                            }
                        </svg>
                    </button>
                </div>
            `;
        }).join('');
        
        // Add event listeners
        list.querySelectorAll('.layer-item').forEach(item => {
            item.addEventListener('click', (e) => {
                if (!e.target.closest('.layer-visibility')) {
                    const index = parseInt(item.dataset.index);
                    const obj = this.canvas.item(index);
                    if (obj && !obj.isBackgroundImage) {
                        this.canvas.setActiveObject(obj);
                        this.canvas.renderAll();
                    }
                }
            });
        });
        
        list.querySelectorAll('.layer-visibility').forEach(btn => {
            btn.addEventListener('click', () => {
                const index = parseInt(btn.dataset.index);
                const obj = this.canvas.item(index);
                if (obj) {
                    obj.visible = !obj.visible;
                    this.canvas.renderAll();
                    this.updateLayersPanel();
                }
            });
        });
    }
    
    moveLayerUp() {
        const obj = this.canvas.getActiveObject();
        if (obj && !obj.isBackgroundImage) {
            obj.bringForward();
            this.canvas.renderAll();
            this.updateLayersPanel();
            this.saveState();
        }
    }
    
    moveLayerDown() {
        const obj = this.canvas.getActiveObject();
        if (obj && !obj.isBackgroundImage) {
            obj.sendBackwards();
            // Make sure background stays at bottom
            if (this.currentImage) {
                this.canvas.sendToBack(this.currentImage);
            }
            this.canvas.renderAll();
            this.updateLayersPanel();
            this.saveState();
        }
    }
    
    deleteSelected() {
        const obj = this.canvas.getActiveObject();
        if (obj && !obj.isBackgroundImage) {
            this.canvas.remove(obj);
            this.canvas.renderAll();
            this.saveState();
        }
    }
    
    duplicateSelected() {
        const obj = this.canvas.getActiveObject();
        if (obj && !obj.isBackgroundImage) {
            obj.clone((cloned) => {
                cloned.set({
                    left: cloned.left + 20,
                    top: cloned.top + 20
                });
                this.canvas.add(cloned);
                this.canvas.setActiveObject(cloned);
                this.canvas.renderAll();
                this.saveState();
            });
        }
    }
    
    // ============================================
    // HISTORY (UNDO/REDO)
    // ============================================
    saveState(markSaved = false) {
        // Remove future states if we're not at the end
        if (this.historyIndex < this.history.length - 1) {
            this.history = this.history.slice(0, this.historyIndex + 1);
        }
        
        // Save current state
        const state = JSON.stringify(this.canvas.toJSON(['name', 'isBackgroundImage', 'selectable', 'evented']));
        this.history.push(state);
        
        // Limit history size
        if (this.history.length > this.maxHistory) {
            this.history.shift();
            if (this.savedHistoryIndex > -1) {
                this.savedHistoryIndex = Math.max(-1, this.savedHistoryIndex - 1);
            }
        } else {
            this.historyIndex++;
        }
        
        this.updateHistoryButtons();

        if (markSaved) {
            this.savedHistoryIndex = this.historyIndex;
        }
        this.hasUnsavedChanges = this.historyIndex !== this.savedHistoryIndex;
    }
    
    undo() {
        if (this.historyIndex > 0) {
            this.historyIndex--;
            this.loadState(this.history[this.historyIndex]);
        }
    }
    
    redo() {
        if (this.historyIndex < this.history.length - 1) {
            this.historyIndex++;
            this.loadState(this.history[this.historyIndex]);
        }
    }
    
    loadState(state) {
        this.canvas.loadFromJSON(state, () => {
            // Find and set current image reference
            const objects = this.canvas.getObjects();
            this.currentImage = objects.find(obj => obj.isBackgroundImage);
            
            this.canvas.renderAll();
            this.updateHistoryButtons();
            this.updateLayersPanel();
            this.hasUnsavedChanges = this.historyIndex !== this.savedHistoryIndex;
        });
    }
    
    updateHistoryButtons() {
        const undoBtn = document.getElementById('btn-undo');
        const redoBtn = document.getElementById('btn-redo');
        
        if (undoBtn) undoBtn.disabled = this.historyIndex <= 0;
        if (redoBtn) redoBtn.disabled = this.historyIndex >= this.history.length - 1;
    }
    
    // ============================================
    // ZOOM
    // ============================================
    zoomIn() {
        this.setZoom(this.zoom * 1.2);
    }
    
    zoomOut() {
        this.setZoom(this.zoom / 1.2);
    }
    
    zoomFit() {
        this.setZoom(1);
    }
    
    setZoom(level) {
        level = Math.max(0.1, Math.min(5, level));
        this.zoom = level;
        
        this.canvas.setZoom(level);
        this.canvas.setWidth(this.canvas.getWidth() * level / this.canvas.getZoom());
        this.canvas.setHeight(this.canvas.getHeight() * level / this.canvas.getZoom());
        
        document.getElementById('zoom-level').textContent = Math.round(level * 100) + '%';
    }
    
    // ============================================
    // RESET
    // ============================================
    resetImage() {
        if (!this.originalImage) return;
        
        if (confirm('Reset all changes? This cannot be undone.')) {
            // Reload original image
            const src = this.originalImage._element?.src || this.originalImage.getSrc();
            this.loadImageFromUrl(src);
        }
    }
    
    // ============================================
    // EXPORT / SAVE
    // ============================================
    showExportModal() {
        const modal = document.getElementById('export-modal');
        const preview = document.getElementById('export-preview-img');
        if (!modal || !preview) return;
        
        // Generate preview
        const dataUrl = this.canvas.toDataURL({
            format: 'png',
            quality: 1
        });
        preview.src = dataUrl;
        
        // Show/hide original file info and replace option
        const originalFileInfo = document.getElementById('original-file-info');
        const replaceBtn = document.getElementById('btn-replace-mode');
        const filenameGroup = document.getElementById('filename-group');
        
        if (this.originalFileId) {
            // Editing an existing file from uploads
            originalFileInfo?.classList.remove('hidden');
            document.getElementById('original-filename').textContent = this.originalFileName || 'Original file';
            replaceBtn?.removeAttribute('disabled');
        } else {
            // New file upload
            originalFileInfo?.classList.add('hidden');
            replaceBtn?.setAttribute('disabled', 'true');
            // Make sure "Save as New" is selected
            document.querySelectorAll('.save-mode-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.mode === 'new');
            });
        }
        
        // Setup save mode buttons
        document.querySelectorAll('.save-mode-btn').forEach(btn => {
            btn.onclick = () => {
                if (btn.hasAttribute('disabled')) return;
                document.querySelectorAll('.save-mode-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                
                const isReplace = btn.dataset.mode === 'replace';
                if (filenameGroup) {
                    filenameGroup.style.display = isReplace ? 'none' : 'block';
                }
            };
        });

        const initialMode = document.querySelector('.save-mode-btn.active')?.dataset.mode || 'new';
        if (filenameGroup) {
            filenameGroup.style.display = initialMode === 'replace' ? 'none' : 'block';
        }
        
        // Setup save to server button
        const saveBtn = document.getElementById('btn-save-to-server');
        if (saveBtn) {
            saveBtn.onclick = () => this.saveToServer();
        }
        
        // Reinitialize icons
        safeCreateIcons();
        
        modal.classList.remove('hidden');
    }
    
    hideExportModal() {
        document.getElementById('export-modal').classList.add('hidden');
    }
    
    downloadImage() {
        const format = document.querySelector('.format-btn.active')?.dataset.format || 'png';
        const quality = parseInt(document.getElementById('export-quality').value) / 100;
        const filename = document.getElementById('export-filename').value || 'edited-image';
        
        const dataUrl = this.canvas.toDataURL({
            format: format === 'jpg' ? 'jpeg' : format,
            quality: quality
        });
        
        // Create download link
        const link = document.createElement('a');
        link.download = `${filename}.${format}`;
        link.href = dataUrl;
        link.click();
        
        this.showToast('Image downloaded successfully!', 'success');
        this.hideExportModal();
    }

    async getCsrfToken(baseUrl) {
        if (this.csrfToken) {
            return this.csrfToken;
        }

        const tokenResponse = await fetch(`${baseUrl}/refresh-csrf`, {
            credentials: 'include'
        });

        if (!tokenResponse.ok) {
            throw new Error('Failed to refresh CSRF token');
        }

        this.csrfToken = await tokenResponse.text();
        return this.csrfToken;
    }
    
    async saveToServer() {
        const format = document.querySelector('.format-btn.active')?.dataset.format || 'png';
        const quality = parseInt(document.getElementById('export-quality').value) / 100;
        const filename = document.getElementById('export-filename').value || 'edited-image';
        const saveMode = document.querySelector('.save-mode-btn.active')?.dataset.mode || 'new';
        const originalFileIdBeforeSave = this.originalFileId;
        
        this.showLoading();
        
        try {
            const dataUrl = this.canvas.toDataURL({
                format: format === 'jpg' ? 'jpeg' : format,
                quality: quality
            });
            
            // Convert to blob
            const response = await fetch(dataUrl);
            const blob = await response.blob();
            
            // Create form data
            const formData = new FormData();
            formData.append('aiz_file', blob, `${filename}.${format}`);
            formData.append('source', 'photo-editor');
            
            // Add replace mode info if replacing original
            if (saveMode === 'replace' && this.originalFileId) {
                formData.append('replace_file_id', this.originalFileId);
                formData.append('keep_previous', '1');
            } else if (saveMode === 'new' && this.originalFileId) {
                formData.append('edited_from_id', this.originalFileId);
            }
            
            const baseUrl = window.location.origin;
            const csrfToken = await this.getCsrfToken(baseUrl);
            
            // Upload to Soko
            const uploadResponse = await fetch(`${baseUrl}/aiz-uploader/upload`, {
                method: 'POST',
                body: formData,
                headers: {
                    'X-CSRF-TOKEN': csrfToken,
                },
                credentials: 'include'
            });
            
            if (!uploadResponse.ok) {
                throw new Error('Upload failed');
            }
            
            const result = await uploadResponse.json();
            
            this.hideLoading();
            this.hideExportModal();
            
            const action = saveMode === 'replace' ? 'replace' : 'new';
            this.showToast(action === 'replace' ? 'Original updated' : 'Saved as new upload', 'success');
            
            // Update the original file reference if saved as new
            if (result && result.id) {
                if (action === 'new') {
                    this.originalFileId = result.id;
                    this.originalFileName = result.file_original_name || `${filename}.${format}`;
                }

                this.clearDraft(originalFileIdBeforeSave);
                this.markAsSaved();

                try {
                    const nextUrl = new URL(window.location.href);
                    nextUrl.searchParams.set('file_id', String(result.id));
                    if (result.file_original_name) nextUrl.searchParams.set('file_name', result.file_original_name);
                    if (result.url) nextUrl.searchParams.set('image', result.url);
                    nextUrl.searchParams.delete('picker');
                    window.history.replaceState(null, '', nextUrl.toString());
                } catch (e) {
                    // noop
                }

                this.postSavedMessage({
                    action,
                    id: result.id,
                    url: result.url,
                    file_name: result.file_name,
                    file_original_name: result.file_original_name,
                    original_file_id: originalFileIdBeforeSave,
                });
            }
            
        } catch (error) {
            console.error('Upload error:', error);
            this.csrfToken = null;
            this.hideLoading();
            this.showToast('Error saving image. Please try downloading instead.', 'error');
        }
    }

    postSavedMessage(payload) {
        try {
            if (window.parent && window.parent !== window) {
                window.parent.postMessage({ type: 'soko-photo-editor:saved', payload }, window.location.origin);
            }
        } catch (e) {
            // noop
        }
    }
    
    // ============================================
    // AUTO-SAVE
    // ============================================
    setupAutoSave() {
        // Auto-save every 30 seconds if there are unsaved changes
        this.autoSaveInterval = setInterval(() => {
            if (this.hasUnsavedChanges && this.currentImage) {
                this.performAutoSave();
            }
        }, 30000);
    }
    
    async performAutoSave() {
        const indicator = document.getElementById('autosave-indicator');
        
        try {
            // Show saving indicator
            indicator?.classList.remove('hidden');
            indicator?.classList.add('saving');
            indicator?.classList.remove('error');
            const span = indicator?.querySelector('span');
            if (span) span.textContent = 'Auto-saving...';

            const key = this.getDraftStorageKey();
            const state = this.historyIndex >= 0 ? this.history[this.historyIndex] : JSON.stringify(this.canvas.toJSON(['name', 'isBackgroundImage', 'selectable', 'evented']));
            const draft = {
                v: 1,
                file_id: this.originalFileId || null,
                file_name: this.originalFileName || null,
                updated_at: Date.now(),
                state,
            };

            localStorage.setItem(key, JSON.stringify(draft));

            // Show success indicator
            indicator?.classList.remove('saving');
            if (span) span.textContent = 'Auto-saved';

            this.markAsSaved();
            
            // Hide indicator after 3 seconds
            setTimeout(() => {
                indicator?.classList.add('hidden');
            }, 3000);
            
        } catch (error) {
            console.error('Auto-save error:', error);
            indicator?.classList.remove('saving');
            indicator?.classList.add('error');
            const span = indicator?.querySelector('span');
            if (span) span.textContent = 'Auto-save failed';
            
            setTimeout(() => {
                indicator?.classList.add('hidden');
            }, 5000);
        }
    }
    
    // ============================================
    // TOAST NOTIFICATIONS
    // ============================================
    showToast(message, type = 'success') {
        // Create toast container if it doesn't exist
        let container = document.querySelector('.toast-container');
        if (!container) {
            container = document.createElement('div');
            container.className = 'toast-container';
            document.body.appendChild(container);
        }
        
        // Create toast
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        
        const icon = type === 'success' ? 'check-circle' : 'alert-circle';
        toast.innerHTML = `
            <i data-lucide="${icon}"></i>
            <span>${message}</span>
        `;
        
        container.appendChild(toast);
        safeCreateIcons();
        
        // Remove after 4 seconds
        setTimeout(() => {
            toast.style.animation = 'slideIn 0.3s ease reverse';
            setTimeout(() => toast.remove(), 300);
        }, 4000);
    }
    
    // ============================================
    // LOADING OVERLAY
    // ============================================
    showLoading() {
        document.getElementById('loading-overlay').classList.remove('hidden');
    }
    
    hideLoading() {
        document.getElementById('loading-overlay').classList.add('hidden');
    }
}

// ============================================
// INITIALIZE EDITOR
// ============================================
document.addEventListener('DOMContentLoaded', () => {
    if (!ensurePhotoEditorDeps()) return;
    window.sokoEditor = new SokoPhotoEditor();
    
    // Parse URL parameters for editing existing files
    const urlParams = new URLSearchParams(window.location.search);
    const fileId = urlParams.get('file_id');
    const fileName = urlParams.get('file_name');
    
    if (fileId) {
        window.sokoEditor.originalFileId = fileId;
        window.sokoEditor.originalFileName = fileName || 'Original file';
    }
    
    // Track unsaved changes
    window.sokoEditor.hasUnsavedChanges = false;
    
    // Setup auto-save
    window.sokoEditor.setupAutoSave();
    
    // Warn before leaving with unsaved changes
    window.addEventListener('beforeunload', (e) => {
        if (window.sokoEditor.hasUnsavedChanges) {
            e.preventDefault();
            e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
        }
    });
});
