
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
