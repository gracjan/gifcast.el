Create screencasts of Emacs from coded scenarios
================================================

Create screencasts of Emacs sessions from coded scenarios.
Write scenario in Emacs Lisp.

Example
-------

```elisp
(gifcast-animation
 hello-world
 (set-frame-size (window-frame (get-buffer-window)) 40 10)
 (progn
   (when (get-buffer "file.txt")
     (kill-buffer "file.txt"))
   (switch-to-buffer (get-buffer-create "file.txt"))
   (delete-other-windows)

   (insert (concat
            "The greeting is:\n"
            "\n"
            "    Hello ")))
 (gifcast-capture)
 (gifcast-keys "W")
 (gifcast-capture)
 (gifcast-keys "o")
 (gifcast-capture)
 (gifcast-keys "e")
 (gifcast-capture)
 (gifcast-keys "l)
 (gifcast-capture)
 (gifcast-keys "d")
 (gifcast-capture)
 (gifcast-generate "hello-world.gif")

 (kill-buffer "file.txt")
 nil)
 ```

Produces this animation:
