;;; gifcast.el --- Create animated gifs from Emacs screenshots    -*- coding: utf-8; lexical-binding: t -*-

;; Copyright:  2015, 2016      Gracjan Polak <gracjanpolak@gmail.com>
;; Keywords: screencast
;; Version: 0.1

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Library for Emacs screencasts. Code execution in lisp, sprinkle
;; with capture functions, generate upload ready gif animations.

;;; Code:

;; We do not want any startup message cluttering message area
(setq inhibit-startup-echo-area-message t)

;; Aquamacs tries to be extra helpful at most inappriopratie moments
(defvar aquamacs-version-check-url)
(setq aquamacs-version-check-url nil)

(defvar gifcast--ns-current-frame-window-id nil
  "Mac OSX native window id of the current frame.")

(defvar gifcast--animation-frame-index nil
  "Current animation frame index.")

(defvar gifcast--frames nil
  "Frames captured so for (in reverse order).")

(defvar gifcast--action-list nil
  "Actions to run on timer.

List of lambdas or functions.

On next timer tick (car gifcast--action-list) will be run and
removed from this list.")

(defvar gifcast--current-buffer nil
  "Gifcast needs to manage current buffer for functions that are
  called from timer events.")

(defun gifcast--run-next-action ()
  "Run next action in gifcast--action-list.

Will start timer if needed to run follow up actions."

  (if (input-pending-p)
      ;; note that shortening the time below 0.1s creates a situation
      ;; when not all events are processed and input-pending-p returns
      ;; t multiple times creating a livelock situation
      (run-at-time 0.1 nil #'gifcast--run-next-action)
    (when (consp gifcast--action-list)
      (funcall (car gifcast--action-list))
      (setq gifcast--action-list (cdr gifcast--action-list))
      (run-at-time 0 nil #'gifcast--run-next-action))))

(defun gifcast-append-action (action)
  "Schedule ACTION to be run after all already scheduled actions."
  (when (null gifcast--action-list)
    (run-at-time 0 nil #'gifcast--run-next-action))
  (setq gifcast--action-list (append gifcast--action-list (list action))))

(defun gifcast--ns-get-current-frame-window-id ()
  "Get native Mac OS X window id of the current frame."

  (with-temp-file "get-window-id.m"
    (insert "
#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CGWindow.h>

int main(int argc, char **argv)
{
    NSArray *windows = (NSArray *)CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements,kCGNullWindowID);
    for(NSDictionary *window in windows) {
        if ([[window objectForKey:(NSString *)kCGWindowOwnerPID] isEqual:[NSNumber numberWithLongLong:atoi(argv[1])]]) {
            if ([[window objectForKey:(NSString *)kCGWindowName] isEqual:[NSString stringWithUTF8String:argv[2]]]) {
                printf(\"%d\\n\", [[window objectForKey:(NSString *)kCGWindowNumber] intValue]);
            }
        }
    }
}
"))
  (with-current-buffer "*Messages*"
    (call-process "clang" nil t nil
                  "get-window-id.m" "-o" "get-window-id" "-framework" "CoreGraphics" "-framework" "Cocoa"))
  (chmod "get-window-id" #o755)
  (catch 'return
    (with-temp-buffer
      (dolist (x '(1))

        (call-process (concat default-directory "get-window-id") nil t nil (number-to-string (emacs-pid))
                      (cdr (assoc 'name (frame-parameters (window-frame (get-buffer-window))))))

        (goto-char (point-min))
        (if (looking-at "[0-9]+")
            (throw 'return (match-string 0))
          (sit-for 1))))))

(defun gifcast--ns-capture (filename)
  "Capture sceenshot of current frame and save it to FILENAME.

Image format will be png."
  (with-current-buffer "*Messages*"
    (let ((args (list (concat "-l" gifcast--ns-current-frame-window-id) "-o" filename))
          (buffer-read-only nil))

      (apply #'call-process "screencapture" nil t nil args))))

(defmacro gifcast-animation (name &rest body)
  "Entry point for animation definitions.

Use at top level like this:

  (gifcast-animate
   (set-frame-size (window-frame (get-buffer-window)) 40 10)
   (when (get-buffer \"main.c\") (kill-buffer \"main.c\"))
   (switch-to-buffer (get-buffer-create \"main.c\"))
   (delete-other-windows)
   (tabbar-mode -1)
   (tool-bar-mode -1)
   (blink-cursor-mode -1)
   (my-mode)

   ...generate animation frames..
   )

Note that this only looks like executable statements, in reality
each form will be executed from a timer triggered
handler. Current buffer will be preserved but still there might
be other context information that needs to be taken care
of. Currently the async mechanism does not look into specific
forms and does not decompose those."
  (let ((decorated-name (intern (concat "gifcast-anim-" (symbol-name name)))))
    `(progn
       (defun ,decorated-name ()
         (interactive)
         (gifcast-append-action
          (lambda ()
            (unless gifcast--ns-current-frame-window-id
              (setq gifcast--ns-current-frame-window-id (gifcast--ns-get-current-frame-window-id)))

            (when (or gifcast--animation-frame-index
                      gifcast--frames)
              (error "There are leftovers from previous animation, gifcast--animation-frame-index is '%S' and gifcast--frames is '%S'"
                     gifcast--animation-frame-index gifcast--frames))
            (setq gifcast--animation-frame-index 1)))

         ,@(mapcar (lambda (item)
                     `(gifcast-append-action
                       (lambda ()
                         (with-current-buffer (or gifcast--current-buffer (current-buffer))
                           ,item
                           ;; preserve current buffer for next action in the list
                           (setq gifcast--current-buffer (current-buffer))))))
                   body))
       (put (quote ,decorated-name) 'gifcast--animation t))))

(defmacro gifcast-animation-0 (name &rest body)
  "Dry run entry point for animation definitions.

It is like `gifcast-animate' but does not execute anything.")

(defun gifcast-keys (keys)
  "Simulate keystrokes KEYS.

Append KEYS to `unread-command-events'. Next async command will
pick those up."
  (setq unread-command-events (append unread-command-events (listify-key-sequence keys))))


(defun gifcast-capture (&optional duration)
  "Capture animation frame and show it for DURATION miliseconds.

If duration is not given then use the default 100ms."

  (redisplay t)
  (let ((frame-file-name (concat "frame-" (number-to-string gifcast--animation-frame-index) ".png")))
    (gifcast--ns-capture frame-file-name)
    (push (list frame-file-name (or duration 100)) gifcast--frames)
    (setq gifcast--animation-frame-index (1+ gifcast--animation-frame-index))))

(defun gifcast-generate (filename)
  "Generate animation to FILENAME.

Take frames collected since last `gifcast-animate' and generate a
GIF animation. FILENAME will be used as a file name for the
animation."
  (with-current-buffer "*Messages*"
    (let ((args (apply #'nconc
                 (mapcar (lambda (frame)
                           (list "-delay" (number-to-string (nth 1 frame)) (nth 0 frame)))
                         (reverse gifcast--frames))))
          (buffer-read-only nil))

      (apply #'call-process "convert" nil t nil
             ;; ImageMagick version of convert supports gif
             ;; optimization with options:
             ;;
             ;; (list "-alpha" "remove")
             ;;
             ;; Note that "-layers" "OptimizePlus" sometimes reduces
             ;; palette too much and that becomes visible as a pink
             ;; background color.
             ;;
             ;; Sadly GraphicsMagick version of convert does not offer
             ;; the functionality. If we checked upfront what version
             ;; is available we would be able to use optimized or
             ;; unoptimized version.
             ;;
             ;; Note also that if you have retina displays then the
             ;; images will appear twice as large as you see it on the
             ;; screen. To detect retina use:
             ;;
             ;; system_profiler SPDisplaysDataType
             ;;
             ;; and adjust IMG tag accordingly.
             (append args (list "-alpha" "remove") (list filename)))
      (mapc (lambda (frame)
              (delete-file (nth 0 frame))) gifcast--frames)
      (setq gifcast--frames nil)
      (setq gifcast--animation-frame-index nil))))

(defun gifcast-generate-batch-and-exit ()
  "Generate all animations defined and exit."
  (gifcast-generate-batch)
  (gifcast-append-action
   (lambda ()
     (kill-emacs 0))))

(defun gifcast-generate-batch ()
  "Generate all animations defined and exit."
  (let ((animations
         (apropos-internal "" #'gifcast-animation-boundp)))
    (message "Animations to generate: %d" (length animations))
    (dolist (animation animations)
      (funcall animation))))

(defun gifcast-animation-boundp (symbol)
  "Return non-nil if SYMBOL names an animation."
  (and (get symbol 'gifcast--animation) t))

(provide 'gifcast)
;;; gifcast ends here
