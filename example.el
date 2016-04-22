;;; example.el --- Example for gifcast.el    -*- coding: utf-8; lexical-binding: t -*-

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

(require 'gifcast)

(gifcast-animation
 hello-world
 (set-frame-size (window-frame (get-buffer-window)) 40 10)
 (progn
   (when (get-buffer "file.txt")
     (kill-buffer "file.txt"))
   (switch-to-buffer (get-buffer-create "file.txt"))
   (delete-other-windows)
   (tabbar-mode -1)
   (tool-bar-mode -1)
   (linum-mode -1)
   (message nil)
   (scroll-bar-mode -1)

   (insert (concat
            "The greeting is:\n"
            "\n"
            "    Hello ")))
 (gifcast-capture)
 (gifcast-keys "W")
 (gifcast-capture)
 (gifcast-keys "o")
 (gifcast-capture)
 (gifcast-keys "r")
 (gifcast-capture)
 (gifcast-keys "l")
 (gifcast-capture)
 (gifcast-keys "d")
 (gifcast-capture)
 (gifcast-keys "!")
 (gifcast-capture)
 (gifcast-generate "hello-world.gif")

 (kill-buffer "file.txt")
 nil)
