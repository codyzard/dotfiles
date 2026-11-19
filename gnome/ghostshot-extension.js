import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';

export default class AutoCaptureScreenshotExtension extends Extension {
    enable() {
        const ui = Main.screenshotUI;
        if (!ui || !ui._areaSelector) return;

        const AreaSelectorClass = ui._areaSelector.constructor;
        const ScreenshotUIClass = ui.constructor;
        const ext = this;

        this._sourceIds = new Set();
        this._isCapturing = false;
        this._isDragging = false;

        const safeIdleAdd = (priority, func) => {
            const id = GLib.idle_add(priority, () => {
                const result = func();
                ext._sourceIds.delete(id);
                return result;
            });
            this._sourceIds.add(id);
        };

        const safeTimeoutAdd = (priority, interval, func) => {
            const id = GLib.timeout_add(priority, interval, () => {
                const result = func();
                ext._sourceIds.delete(id);
                return result;
            });
            this._sourceIds.add(id);
        };

        // Hide/show only the visual box + corner handles, keeping _areaSelector itself
        // at opacity 255 so pointer picking always stays active.
        const setVisualsVisible = (sel, visible) => {
            if (!sel) return;
            const op = visible ? 255 : 0;
            if (sel._areaIndicator) sel._areaIndicator.opacity = op;
            if (sel._topLeftHandle) sel._topLeftHandle.opacity = op;
            if (sel._topRightHandle) sel._topRightHandle.opacity = op;
            if (sel._bottomLeftHandle) sel._bottomLeftHandle.opacity = op;
            if (sel._bottomRightHandle) sel._bottomRightHandle.opacity = op;
        };

        // --- WORKAROUND FOR MUTTER 51 INVISIBLE CROSSHAIR BUG ---
        // In Mutter 51, Clutter.CursorType.CROSSHAIR can fail texture upload
        // ("cogl_texture_2d_new_from_data: assertion 'data != NULL' failed"),
        // making the cursor vanish outside the screenshot panel. Fall back to DEFAULT.
        this._hasCustomSetCursorType = true;
        AreaSelectorClass.prototype.set_cursor_type = function(cursor) {
            const safeCursor = (cursor === Clutter.CursorType.CROSSHAIR)
                ? Clutter.CursorType.DEFAULT
                : (cursor ?? Clutter.CursorType.INHERIT);
            return Clutter.Actor.prototype.set_cursor_type.call(this, safeCursor);
        };

        // --- PART 1: REVEAL SELECTION BOX IMMEDIATELY ON DRAG (GNOME 45-51) ---
        this._dragStartedId = ui._areaSelector.connect('drag-started', () => {
            ext._isDragging = true;
            ui._areaSelector.remove_all_transitions();
            ui._areaSelector.opacity = 255;
            setVisualsVisible(ui._areaSelector, true);
        });

        // --- PART 2: AUTO-CAPTURE ON RELEASE ---
        this._origStopDrag = AreaSelectorClass.prototype.stopDrag;

        AreaSelectorClass.prototype.stopDrag = function() {
            const wasDragging = ext._isDragging;
            ext._isDragging = false;

            const wasClickWithoutDrag = (
                this._dragCursor === Clutter.CursorType.CROSSHAIR &&
                this._lastX === this._startX &&
                this._lastY === this._startY
            );

            ext._origStopDrag.apply(this, arguments);

            if (wasDragging && !ext._isCapturing && !wasClickWithoutDrag) {
                ext._isCapturing = true;
                safeIdleAdd(GLib.PRIORITY_DEFAULT, () => {
                    const activeUI = Main.screenshotUI;
                    if (activeUI && activeUI._captureButton && activeUI._captureButton.visible) {
                        activeUI._captureButton.emit('clicked', 0);
                    }
                    safeTimeoutAdd(GLib.PRIORITY_DEFAULT, 500, () => {
                        ext._isCapturing = false;
                        return GLib.SOURCE_REMOVE;
                    });
                    return GLib.SOURCE_REMOVE;
                });
            }
        };

        // --- PART 3: RESET OLD BOX OFF-SCREEN & KEEP VISIBLE CURSOR ON OPEN ---
        const resetAndHideSelector = (container) => {
            const sel = container && container._areaSelector;
            if (!sel) return;
            ext._isDragging = false;
            sel.remove_all_transitions();
            sel.opacity = 255;
            sel._startX = -1000;
            sel._startY = -1000;
            sel._lastX = -1000;
            sel._lastY = -1000;
            if (typeof sel._updateSelectionRect === 'function') {
                sel._updateSelectionRect();
            }
            setVisualsVisible(sel, false);
            sel.set_cursor_type(Clutter.CursorType.CROSSHAIR);
        };

        this._origOnSelectionButtonToggled = ScreenshotUIClass.prototype._onSelectionButtonToggled;
        if (this._origOnSelectionButtonToggled) {
            ScreenshotUIClass.prototype._onSelectionButtonToggled = function() {
                const res = ext._origOnSelectionButtonToggled.apply(this, arguments);
                if (this._selectionButton && this._selectionButton.checked) {
                    resetAndHideSelector(this);
                }
                return res;
            };
        }

        this._origOpen = ScreenshotUIClass.prototype.open;
        ScreenshotUIClass.prototype.open = async function() {
            const result = await ext._origOpen.apply(this, arguments);
            resetAndHideSelector(this);
            return result;
        };
    }

    disable() {
        const ui = Main.screenshotUI;

        if (this._sourceIds) {
            this._sourceIds.forEach(id => GLib.source_remove(id));
            this._sourceIds.clear();
        }

        if (ui) {
            const AreaSelectorClass = ui._areaSelector?.constructor;
            const UIClass = ui.constructor;

            if (this._hasCustomSetCursorType && AreaSelectorClass) {
                delete AreaSelectorClass.prototype.set_cursor_type;
            }
            if (this._dragStartedId && ui._areaSelector) {
                ui._areaSelector.disconnect(this._dragStartedId);
            }
            if (this._origStopDrag && AreaSelectorClass) {
                AreaSelectorClass.prototype.stopDrag = this._origStopDrag;
            }
            if (this._origOpen) {
                UIClass.prototype.open = this._origOpen;
            }
            if (this._origOnSelectionButtonToggled) {
                UIClass.prototype._onSelectionButtonToggled = this._origOnSelectionButtonToggled;
            }
            if (ui._areaSelector) {
                ui._areaSelector.opacity = 255;
                if (ui._areaSelector._areaIndicator) ui._areaSelector._areaIndicator.opacity = 255;
                if (ui._areaSelector._topLeftHandle) ui._areaSelector._topLeftHandle.opacity = 255;
                if (ui._areaSelector._topRightHandle) ui._areaSelector._topRightHandle.opacity = 255;
                if (ui._areaSelector._bottomLeftHandle) ui._areaSelector._bottomLeftHandle.opacity = 255;
                if (ui._areaSelector._bottomRightHandle) ui._areaSelector._bottomRightHandle.opacity = 255;
            }
        }

        this._hasCustomSetCursorType = false;
        this._dragStartedId = null;
        this._origStopDrag = null;
        this._origOpen = null;
        this._origOnSelectionButtonToggled = null;
        this._isDragging = false;
    }
}
