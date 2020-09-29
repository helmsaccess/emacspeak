;;; emacspeak-wizards.el --- Magic For Power Users   -*- lexical-binding: t; -*-
;;; $Id$
;;; $Author: tv.raman.tv $
;;; Description:  Contains convenience wizards
;;; Keywords: Emacspeak,  Audio Desktop Wizards
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;;; A speech interface to Emacs |
;;; $Date: 2008-08-15 10:08:11 -0700 (Fri, 15 Aug 2008) $ |
;;;  $Revision: 4638 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:

;;;Copyright (C) 1995 -- 2018, T. V. Raman
;;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction

;;; Commentary:

;;; Contains various wizards for the Emacspeak desktop.

;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl-lib)
(cl-declaim (optimize (safety 0) (speed 3)))
(eval-when-compile (require 'subr-x))
(require 'let-alist)
(require 'emacspeak-preamble)
(eval-when-compile
  (require 'calendar)
  (require 'cus-edit)
  (require 'derived)
  (require 'desktop)
  (require 'emacspeak-table-ui)
  (require 'emacspeak-we)
  (require 'emacspeak-xslt)
  (require 'find-dired)
  (require 'gweb)
  (require 'lisp-mnt)
  (require 'name-this-color "name-this-color" 'no-error)
  (require 'org)
  (require 'shell)
  (require 'solar)
  (require 'term)
  (require 'texinfo)
  )

;;}}}
;;{{{Forward Decls:

(declare-function org-table-previous-row "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-current-element "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-coordinates "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-both-headers-and-element "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-row-header-and-element "emacspeak-org" nil)
(declare-function emacspeak-org-table-speak-column-header-and-element "emacspeak-org" nil)

;;}}}
;;{{{defgroup:
(defgroup emacspeak-wizards nil
  "Wizards for the Emacspeak desktop."
  :group 'emacspeak
  :prefix "emacspeak-wizards-")

;;}}}
;;{{{Read JSON file:

(defsubst ems--json-read-file (filename)
  "Use native json implementation if available to read json file."
  (cond
   ((fboundp 'json-parse-buffer)
    (with-current-buffer (find-file-noselect filename)
      (goto-char (point-min))
      (prog1
          (json-parse-buffer :object-type 'alist)
        (kill-buffer ))))
   (t (json-read-file filename))))

;;}}}
;;{{{  Actions

;;; Setting value of property 'emacspeak-action to a list
;;; of the form (before | after function)
;;; function to be executed before or after the unit of text at that
;;; point is spoken.

(defvar emacspeak-action-mode nil
  "Determines if action mode is active.
Non-nil value means that any function that is set as the
value of property action is executed when the text at that
point is spoken.")

(make-variable-buffer-local 'emacspeak-action-mode)

;;; Record in the mode line
(or
 (assq 'emacspeak-action-mode minor-mode-alist)
 (setq minor-mode-alist
       (append minor-mode-alist
               '((emacspeak-action-mode " Action")))))

;;; Return the appropriate action hook variable that defines actions
;;; for this mode.

(defun emacspeak-action-get-action-hook (mode)
  "Retrieve action hook.
Argument MODE defines action mode."
  (intern (format "emacspeak-%s-actions-hook" mode)))

;;; Execute action at point
(defun emacspeak-handle-action-at-point (&optional pos)
  "Execute action specified at point."
  (cl-declare (special emacspeak-action-mode))
  (setq pos (or pos (point)))
  (let ((action-spec (get-text-property (point) 'emacspeak-action)))
    (when (and emacspeak-action-mode action-spec)
      (condition-case nil
          (funcall action-spec)
        (error (message "Invalid actionat %s" (point)))))))

(ems-generate-switcher 'emacspeak-toggle-action-mode
                       'emacspeak-action-mode
                       "Toggle state of  Emacspeak  action mode.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")

;;}}}
;;{{{  Emacspeak News and Documentation


(defun emacspeak-view-emacspeak-news ()
  "Display emacspeak News for a given version."
  (interactive)
  (cl-declare (special emacspeak-etc-directory))
  (find-file-read-only
   (expand-file-name
    (completing-read "News: "
                     (directory-files emacspeak-etc-directory nil "NEWS*"))
    emacspeak-etc-directory))
  (emacspeak-auditory-icon 'news)
  (org-mode)
  (org-next-visible-heading 1)
  (emacspeak-speak-line))


(defun emacspeak-view-emacspeak-tips ()
  "Browse  Emacspeak productivity tips."
  (interactive)
  (cl-declare (special emacspeak-etc-directory))
  (emacspeak-xslt-without-xsl
   (browse-url
    (format "file:///%stips.html"
            emacspeak-etc-directory)))
  (emacspeak-auditory-icon 'help)
  (emacspeak-speak-mode-line))

;;}}}
;;{{{ utility function to copy documents:

(defvar emacspeak-copy-file-location-history nil
  "History list for prompting for a copy location.")

(defvar emacspeak-copy-associated-location nil
  "Buffer local variable that records where we copied this document last.")

(make-variable-buffer-local
 'emacspeak-copy-associated-location)

(defun emacspeak-copy-current-file ()
  "Copy file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when copying.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Asks for confirmation if the copy will result in an
  existing file being overwritten."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Copy current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (copy-file
     file location
     1                                  ;prompt before overwriting
     t                                  ;preserve
                                        ;modification time
     )
    (emacspeak-auditory-icon 'select-object)
    (message "Copied current document to %s" location)))

(defun emacspeak-link-current-file ()
  "Link (hard link) file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when linking.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Signals an error if target already exists."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Link current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (add-name-to-file
     file location)
    (emacspeak-auditory-icon 'select-object)
    (message "Linked current document to %s" location)))

(defun emacspeak-symlink-current-file ()
  "Link (symbolic link) file visited in current buffer to new location.
Prompts for the new location and preserves modification time
  when linking.  If location is a directory, the file is copied
  to that directory under its current name ; if location names
  a file in an existing directory, the specified name is
  used.  Signals an error if target already exists."
  (interactive)
  (cl-declare (special emacspeak-copy-file-location-history
                       emacspeak-copy-associated-location))
  (let ((file (or (buffer-file-name)
                  (error "Current buffer is not visiting any file")))
        (location (read-file-name
                   "Symlink current file to location: "
                   emacspeak-copy-associated-location ;default
                   (car
                    emacspeak-copy-file-location-history)))
        (minibuffer-history (or
                             emacspeak-copy-file-location-history
                             minibuffer-history)))
    (setq emacspeak-copy-associated-location location)
    (when (file-directory-p location)
      (unless (string-equal location (car emacspeak-copy-file-location-history))
        (push location emacspeak-copy-file-location-history))
      (setq location
            (expand-file-name
             (file-name-nondirectory file)
             location)))
    (make-symbolic-link
     file location)
    (emacspeak-auditory-icon 'select-object)
    (message "Symlinked  current doc>ument to %s" location)))

;;}}}
;;{{{ pop up messages buffer

;;; Internal variable to memoize window configuration

(defvar emacspeak-popup-messages-config-0 nil
  "Memoizes window configuration.")
;;;###autoload
(defun emacspeak-speak-popup-messages ()
  "Pop up messages buffer.
If it is already selected then hide it and try to restore
previous window configuration."
  (interactive)
  (cond
;;; First check if Messages buffer is already selected
   ((string-equal (buffer-name (window-buffer (selected-window)))
                  "*Messages*")
    (when (window-configuration-p emacspeak-popup-messages-config-0)
      (set-window-configuration emacspeak-popup-messages-config-0))
    (setq emacspeak-popup-messages-config-0 nil)
    (bury-buffer "*Messages*")
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-mode-line))
                                        ; popup Messages buffer
   (t
;;; Memoize current window configuration only if buffer isn't yet visible
    (setq emacspeak-popup-messages-config-0
          (and (not (get-buffer-window "*Messages*"))
               (current-window-configuration)))
    (pop-to-buffer "*Messages*" nil t)
                                        ; position cursor on the last message
    (goto-char (point-max))
    (beginning-of-line (and (bolp) 0))
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-line))))

;;}}}
;;{{{ Network interface utils:

(defun ems-get-active-network-interfaces ()
  "Return  names of active network interfaces."
  (when (fboundp 'network-interface-list)
     (seq-uniq (mapcar #'car (network-interface-list)))))

(defvar emacspeak-speak-network-interfaces-list
  (ems-get-active-network-interfaces)
  "Used when prompting for an interface to query.")

(defun ems-get-ip-address (dev)
  "get the IP-address for device DEV "
  (setq dev
        (or dev
            (completing-read
             "Device: "
             (ems-get-active-network-interfaces) nil t)))
  (format-network-address
   (car (network-interface-info dev))
   'omit-port))

;;}}}
;;{{{ Show active network interfaces


(defun emacspeak-speak-hostname ()
  "Speak host name."
  (interactive)
  (message (system-name)))


(defun emacspeak-speak-show-active-network-interfaces (&optional address)
  "Shows all active network interfaces in the echo area.
With interactive prefix argument ADDRESS it prompts for a
specific interface and shows its address. The address is
also copied to the kill ring for convenient yanking."
  (interactive "P")
  (kill-new
   (message
    (if address
        (ems-get-ip-address nil)
      (mapconcat #'identity 
                 (ems-get-active-network-interfaces)
                 " ")))))

;;}}}
;;{{{ Elisp Utils:

(defun emacspeak-wizards-next-interactive-defun ()
  "Move point to the next interactive defun"
  (interactive)
  (end-of-defun)
  (re-search-forward "^ *(interactive")
  (beginning-of-defun)
  (emacspeak-speak-line))

;;}}}
;;{{{  simple phone book

(defcustom emacspeak-speak-telephone-directory
  (expand-file-name "tel-dir" emacspeak-resource-directory)
  "File holding telephone directory.
This is just a text file, and we use grep to search it."
  :group 'emacspeak-speak
  :type 'string)

(defcustom emacspeak-speak-telephone-directory-command
  "grep -i "
  "Command used to look up names in the telephone
directory."
  :group 'emacspeak-speak
  :type 'string)
;;;###autoload
(defun emacspeak-speak-telephone-directory (&optional edit)
  "Lookup and display a phone number.
With prefix arg, opens the phone book for editing."
  (interactive "P")
  (cond
   (edit
    (find-file emacspeak-speak-telephone-directory)
    (emacspeak-speak-mode-line)
    (emacspeak-auditory-icon 'open-object))
   ((file-exists-p emacspeak-speak-telephone-directory)
    (emacspeak-shell-command
     (format "%s %s %s"
             emacspeak-speak-telephone-directory-command
             (read-from-minibuffer "Lookup number for: ")
             emacspeak-speak-telephone-directory))
    (emacspeak-speak-message-again))
   (t (error "First create your phone directory in %s"
             emacspeak-speak-telephone-directory))))

;;}}}
;;{{{ find file as root

;;; http://emacs-fu.blogspot.com/
;;; 2013/03/editing-with-root-privileges-once-more.html
;;;###autoload
(defun emacspeak-wizards-find-file-as-root (file)
  "Like `ido-find-file, but automatically edit the file with
root-privileges (using tramp/sudo), if the file is not writable by
user."
  (interactive
   (list
    (cond
     ((eq major-mode 'dired-mode) (dired-file-name-at-point))
     (t (ido-read-file-name "Edit as root: ")))))
  (unless (file-writable-p file)
    (setq file (concat "/sudo:root@localhost:" file)))
  (find-file file)
  (when (called-interactively-p 'interactive)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{ edit file as root using sudo vi

;;}}}
;;{{{ browse chunks


(defun emacspeak-wizards-move-and-speak (command count)
  "Speaks a chunk of text bounded by point and a target position.
Target position is specified using a navigation command and a
count that specifies how many times to execute that command
first.  Point is left at the target position.  Interactively,
command is specified by pressing the key that invokes the
command."
  (interactive
   (list
    (lookup-key global-map
                (read-key-sequence "Key:"))
    (read-minibuffer "Count:")))
  (let ((orig (point)))
    (push-mark orig)
    (funcall command count)
    (emacspeak-speak-region orig (point))))

;;}}}
;;{{{  Learn mode

;;;###autoload
(defun emacspeak-learn-emacs-mode ()
  "Helps you learn the keys.  You can press keys and hear what they do.
To leave, press \\[keyboard-quit]."
  (interactive)
  (let ((continue t)
        (dtk-stop-immediately nil))
    (while continue
      (call-interactively 'describe-key-briefly)
      (sit-for 1)
      (when (and (numberp last-input-event)
                 (= last-input-event 7))
        (setq continue nil)))
    (message "Leaving learn mode ")))

(defun emacspeak-describe-emacspeak ()
  "Give a brief overview of emacspeak."
  (interactive)
  (describe-function 'emacspeak)
  (switch-to-buffer "*Help*")
  (dtk-set-punctuations 'all)
  (emacspeak-speak-buffer))

;;}}}
;;{{{ labelled frames

(defun emacspeak-frame-read-frame-label ()
  "Read a frame label with completion."
  (let* ((frame-names-alist (make-frame-names-alist))
         (default (car (car frame-names-alist)))
         (input (completing-read
                 (format "Select Frame (default %s): " default)
                 frame-names-alist nil t nil 'frame-name-history)))
    (if (= (length input) 0)
        default)))
;;;###autoload
(defun emacspeak-frame-label-or-switch-to-labelled-frame (&optional prefix)
  "Switch to labelled frame.
With optional PREFIX argument, label current frame."
  (interactive "P")
  (cond
   (prefix
    (call-interactively 'set-frame-name))
   (t (call-interactively 'select-frame-by-name)))
  (when (called-interactively-p 'interactive)
    (emacspeak-speak-mode-line)
    (emacspeak-auditory-icon 'select-object)))

;;;###autoload
(defun emacspeak-next-frame-or-buffer (&optional frame)
  "Move to next buffer.
With optional interactive prefix arg `frame', move to next frame instead."
  (interactive "P")
  (cond
   (frame (funcall-interactively #'other-frame 1))
   (t (call-interactively #'next-buffer))))

;;;###autoload
(defun emacspeak-previous-frame-or-buffer (&optional frame)
  "Move to previous buffer.
With optional interactive prefix arg `frame', move to previous frame instead."
  (interactive "P")
  (cond
   (frame (funcall-interactively #'other-frame -1))
   (t (call-interactively #'previous-buffer))))

;;}}}
;;{{{  readng different displays of same buffer
;;;###autoload
(defun emacspeak-speak-this-buffer-other-window-display (&optional arg)
  "Speak this buffer as displayed in a different frame.  Emacs
allows you to display the same buffer in multiple windows or
frames.  These different windows can display different
portions of the buffer.  This is equivalent to leaving a
book open at places at once.  This command allows you to
listen to the places where you have left the book open.  The
number used to invoke this command specifies which of the
displays you wish to speak.  Typically you will have two or
at most three such displays open.  The current display is 0,
the next is 1, and so on.  Optional argument ARG specifies
the display to speak."
  (interactive "P")
  (let ((window
         (or arg
             (condition-case nil
                 (read (format "%c" last-input-event))
               (error nil))))
        (win nil)
        (window-list (get-buffer-window-list
                      (current-buffer)
                      nil 'visible)))
    (or (numberp window)
        (setq window
              (read-minibuffer "Display    to speak")))
    (setq win
          (nth (% window (length window-list))
               window-list))
    (save-excursion
      (save-window-excursion
        (emacspeak-speak-region
         (window-point win)
         (window-end win))))))
;;;###autoload
(defun emacspeak-speak-this-buffer-previous-display ()
  "Speak this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-speak-this-buffer-other-window-display' for the
meaning of `previous'."
  (interactive)
  (let ((count (length (get-buffer-window-list
                        (current-buffer)
                        nil 'visible))))
    (emacspeak-speak-this-buffer-other-window-display (1- count))))
;;;###autoload
(defun emacspeak-speak-this-buffer-next-display ()
  "Speak this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-speak-this-buffer-other-window-display' for the
meaning of `next'."
  (interactive)
  (emacspeak-speak-this-buffer-other-window-display 1))
;;;###autoload
(defun emacspeak-select-this-buffer-other-window-display (&optional arg)
  "Switch  to this buffer as displayed in a different frame.  Emacs
allows you to display the same buffer in multiple windows or
frames.  These different windows can display different
portions of the buffer.  This is equivalent to leaving a
book open at multiple places at once.  This command allows you to
move to the places where you have left the book open.  The
number used to invoke this command specifies which of the
displays you wish to select.  Typically you will have two or
at most three such displays open.  The current display is 0,
the next is 1, and so on.  Optional argument ARG specifies
the display to select."
  (interactive "P")
  (let ((window
         (or arg
             (condition-case nil
                 (read (format "%c" last-input-event))
               (error nil))))
        (win nil)
        (window-list (get-buffer-window-list
                      (current-buffer)
                      nil 'visible)))
    (or (numberp window)
        (setq window
              (read-minibuffer "Display to select")))
    (setq win
          (nth (% window (length window-list))
               window-list))
    (select-frame (window-frame win))
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'select-object)))
;;;###autoload
(defun emacspeak-select-this-buffer-previous-display ()
  "Select this buffer as displayed in a `previous' window.
See documentation for command
`emacspeak-select-this-buffer-other-window-display' for the
meaning of `previous'."
  (interactive)
  (let ((count (length (get-buffer-window-list
                        (current-buffer)
                        nil 'visible))))
    (emacspeak-select-this-buffer-other-window-display (1- count))))
;;;###autoload
(defun emacspeak-select-this-buffer-next-display ()
  "Select this buffer as displayed in a `next' frame.
See documentation for command
`emacspeak-select-this-buffer-other-window-display' for the
meaning of `next'."
  (interactive)
  (emacspeak-select-this-buffer-other-window-display 1))

;;}}}
;;{{{ emacspeak clipboard

(cl-eval-when (load)
  (condition-case nil
      (unless (file-exists-p emacspeak-resource-directory)
        (make-directory emacspeak-resource-directory))
    (error (message "Make sure you have an Emacspeak resource directory %s"
                    emacspeak-resource-directory))))

(defcustom emacspeak-clipboard-file
  (concat emacspeak-resource-directory "/" "clipboard")
  "File used to save Emacspeak clipboard.
The emacspeak clipboard provides a convenient mechanism for exchanging
information between different Emacs sessions."
  :group 'emacspeak-speak
  :type 'string)
;;;###autoload
(defun emacspeak-clipboard-copy (start end &optional prompt)
  "Copy contents of the region to the emacspeak clipboard. Previous
contents of the clipboard will be overwritten. The Emacspeak clipboard
is a convenient way of sharing information between independent
Emacspeak sessions running on the same or different machines. Do not
use this for sharing information within an Emacs session --Emacs'
register commands are far more efficient and light-weight. Optional
interactive prefix arg results in Emacspeak prompting for the
clipboard file to use. Argument START and END specifies
region. Optional argument PROMPT specifies whether we prompt for the
name of a clipboard file."
  (interactive "r\nP")
  (cl-declare (special emacspeak-resource-directory emacspeak-clipboard-file))
  (let ((clip (buffer-substring-no-properties start end))
        (clipboard-file
         (if prompt
             (read-file-name "Copy region to clipboard file: "
                             emacspeak-resource-directory
                             emacspeak-clipboard-file)
           emacspeak-clipboard-file))
        (clipboard nil))
    (setq clipboard (find-file-noselect clipboard-file))
    (ems-with-messages-silenced
     (save-current-buffer
       (set-buffer clipboard)
       (erase-buffer)
       (insert clip)
       (save-buffer)))
    (message "Copied %s lines to Emacspeak clipboard %s"
             (count-lines start end)
             clipboard-file)))
;;;###autoload
(defun emacspeak-clipboard-paste (&optional paste-table)
  "Yank contents of the Emacspeak clipboard at point.
The Emacspeak clipboard is a convenient way of sharing information between
independent Emacspeak sessions running on the same or different
machines.  Do not use this for sharing information within an Emacs
session --Emacs' register commands are far more efficient and
light-weight.  Optional interactive prefix arg pastes from
the emacspeak table clipboard instead."
  (interactive "P")
  (cl-declare (special emacspeak-resource-directory emacspeak-clipboard-file))
  (let ((start (point))
        (clipboard-file emacspeak-clipboard-file))
    (cond
     (paste-table (emacspeak-table-paste-from-clipboard))
     (t (insert-file-contents clipboard-file)
        (exchange-point-and-mark)))
    (message "Yanked %s lines from  Emacspeak clipboard %s"
             (count-lines start (point))
             (if paste-table "table clipboard"
               clipboard-file))))

;;}}}
;;{{{ Emacs Dev utilities

;;;###autoload
(defun emacspeak-wizards-show-eval-result (form)
  "Convenience command to pretty-print and view Lisp evaluation results."
  (interactive
   (list
    (let ((minibuffer-completing-symbol t))
      (read-from-minibuffer "Eval: "
                            nil read-expression-map t
                            'read-expression-history))))
  (cl-declare (special read-expression-map))
  (let ((buffer (get-buffer-create "*emacspeak:Eval*"))
        (print-length nil)
        (print-level nil)
        (result (eval form)))
    (save-current-buffer
      (set-buffer buffer)
      (setq buffer-undo-list t)
      (erase-buffer)
      (cl-prettyprint result)
      (set-buffer-modified-p nil))
    (pop-to-buffer buffer)
    (emacs-lisp-mode)
    (goto-char (point-min))
    (forward-line 1)

    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))


(defun emacspeak-wizards-show-memory-used ()
  "Convenience command to view state of memory used in this session so far."
  (interactive)
  (let ((buffer (get-buffer-create "*emacspeak-memory*")))
    (save-current-buffer
      (set-buffer buffer)
      (erase-buffer)
      (insert
       (apply 'format
              "Memory Statistics
 cons cells:\t%d
 floats:\t%d
 vectors:\t%d
 symbols:\t%d
 strings:\t%d
 miscellaneous:\t%d
 integers:\t%d\n"
              (memory-use-counts)))
      (insert "\nInterpretation of these statistics:\n")
      (insert (documentation 'memory-use-counts))
      (goto-char (point-min)))
    (pop-to-buffer buffer)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{ emergency tts restart

(defcustom emacspeak-emergency-tts-server
  "outloud"
  "TTS server to use in an emergency.
Set this to a TTS server that is known to work at all times.
If you are debugging another speech server and that server
gets wedged for some reason,
you can use command emacspeak-emergency-tts-restart
to get speech back using the reliable TTS server.
It's useful to bind the above command to a convenient key."
  :type 'string
  :group 'emacspeak)
;;;###autoload
(defun emacspeak-emergency-tts-restart ()
  "For use in an emergency.
Will start TTS engine specified by
emacspeak-emergency-tts-server."
  (interactive)
  (cl-declare (special emacspeak-emergency-tts-server))
  (funcall-interactively #'dtk-select-server emacspeak-emergency-tts-server))

(defcustom emacspeak-ssh-tts-server
  "ssh-outloud"
  "SSH TTS server to use by default."
  :type 'string
  :group 'emacspeak)

;;;###autoload
(defun emacspeak-ssh-tts-restart ()
  "Restart specified ssh tts server."
  (interactive)
  (cl-declare (special emacspeak-ssh-tts-server))
  (dtk-select-server emacspeak-ssh-tts-server)
  (dtk-initialize))

;;}}}
;;{{{  Display properties conveniently

;;; Useful for developping emacspeak:
;;; Display selected properties of interest

(defvar emacspeak-property-table
  '(("personality" . "personality")
    ("auditory-icon" . "auditory-icon")
    ("action" . "action"))
  "Properties emacspeak is interested in.")

;;;###autoload
(defun emacspeak-show-style-at-point ()
  "Show value of property personality (and possibly face) at point."
  (interactive)
  (let ((f (get-text-property (point) 'face))
        (style (dtk-get-style))
        (msg nil))
    (setq msg
          (concat
           (propertize
            (format "%s" (or style "No Style "))
            'personality 'voice-bolden)
           (if style " is "  "")
           (propertize
            (format "%s"
                    (cond
                     ((null style) "")
                     ((listp style)
                      (mapconcat
                       #'(lambda (s)
                           (format "%s" (if (boundp s) (symbol-value s) "")))
                       style " "))
                     ((boundp style) (symbol-value style))))
            'personality 'voice-smoothen)
           (if f " for " "")
           (propertize
            (format "%s" (or f ""))
            'face f)))
    (message msg)))

;;;###autoload
(defun emacspeak-show-property-at-point (&optional property)
  "Show value of PROPERTY at point.
If optional arg property is not supplied, read it interactively.
Provides completion based on properties at point.
If no property is set, show a message and exit."
  (interactive
   (let
       ((properties (text-properties-at (point))))
     (cond
      ((and properties
            (= 2 (length properties)))
       (list (car properties)))
      (properties
       (list
        (intern
         (completing-read
          "Display property: "
          (cl-loop
           for p in properties and i from 0 if (cl-evenp i) collect p)))))
      (t (message "No property set at point ")
         nil))))
  (if property
      (kill-new
       (message "%s"
                (get-text-property (point) property)))))

;;}}}
;;{{{  moving across blank lines
;;;###autoload
(defun emacspeak-skip-blank-lines-forward ()
  "Move forward across blank lines.
The line under point is then spoken.
Signals end of buffer."
  (interactive)
  (let ((save-syntax (char-syntax 10))
        (start (point))
        (newlines nil)
        (skipped nil)
        (skip 0))
    (unwind-protect
        (progn
          (modify-syntax-entry 10 " ")
          (end-of-line)
          (setq skip (skip-syntax-forward " "))
          (cond
           ((zerop skip)
            (message "Did not move "))
           ((eobp)
            (message "At end of buffer"))
           (t
            (beginning-of-line)
            (setq newlines (1- (count-lines start (point))))
            (when (> newlines 0)
              (setq skipped
                    (format "skip %d " newlines))
              (put-text-property 0 (length skipped)
                                 'personality
                                 voice-annotate skipped))
            (emacspeak-auditory-icon 'select-object)
            (dtk-speak
             (concat skipped (ems--this-line))))))
      (modify-syntax-entry 10 (format "%c" save-syntax)))))
;;;###autoload
(defun emacspeak-skip-blank-lines-backward ()
  "Move backward  across blank lines.
The line under point is   then spoken.
Signals beginning  of buffer."
  (interactive)
  (let ((save-syntax (char-syntax 10))
        (newlines nil)
        (start (point))
        (skipped nil)
        (skip 0))
    (unwind-protect
        (progn
          (modify-syntax-entry 10 " ")
          (beginning-of-line)
          (setq skip (skip-syntax-backward " "))
          (cond
           ((zerop skip)
            (message "Did not move "))
           ((bobp)
            (message "At start  of buffer"))
           (t
            (beginning-of-line)
            (setq newlines (1- (count-lines start (point))))
            (when (> newlines 0)
              (setq skipped (format "skip %d " newlines))
              (put-text-property 0 (length skipped)
                                 'personality
                                 voice-annotate skipped))
            (emacspeak-auditory-icon 'select-object)
            (dtk-speak
             (concat skipped (ems--this-line))))))
      (modify-syntax-entry 10 (format "%c" save-syntax)))))

;;}}}
;;{{{  launch Curl

(defcustom emacspeak-curl-cookie-store
  (expand-file-name "~/.curl-cookies")
  "Cookie store used by Curl."
  :type 'file
  :group 'emacspeak-wizards)


(defun emacspeak-curl (url)
  "Grab URL using Curl, and preview it with a browser ."
  (interactive "sURL: ")
  (cl-declare (special emacspeak-curl-program
                       emacspeak-curl-cookie-store))
  (with-temp-buffer
    (shell-command
     (format
      "%s -s --location-trusted --cookie-jar %s --cookie %s '%s'
2>/dev/null"
      emacspeak-curl-program
      emacspeak-curl-cookie-store emacspeak-curl-cookie-store url)
     (current-buffer))
    (browse-url-of-buffer)))

;;}}}
;;{{{ ansi term

;;;###autoload
(defun emacspeak-wizards-terminal (program)
  "Launch terminal and rename buffer appropriately."
  (interactive (list (read-from-minibuffer "Run program: ")))
  (switch-to-buffer-other-frame
   (ansi-term program
              (cl-first (split-string program))))
  (delete-other-windows)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-mode-line))

;;}}}
;;{{{ annotation wizard

;;; I use this to collect my annotations into a buffer
;;; e.g. an email message to be sent out--
;;; while reading and commenting on large documents.

(defun emacspeak-annotate-make-buffer-list (&optional buffer-list)
  "Returns names from BUFFER-LIST excluding those beginning with a space."
  (let (buf-name)
    (delq nil (mapcar
               #'(lambda (b)
                   (setq buf-name (buffer-name b))
                   (and (stringp buf-name)
                        (/= (length buf-name) 0)
                        (/= (aref buf-name 0) ?\ )
                        b))
               (or buffer-list
                   (buffer-list))))))

(defvar emacspeak-annotate-working-buffer nil
  "Buffer that annotations go to.")

(make-variable-buffer-local 'emacspeak-annotate-working-buffer)

(defvar emacspeak-annotate-edit-buffer
  "*emacspeak-annotation*"
  "Name of temporary buffer used to edit the annotation.")

(defun emacspeak-annotate-get-annotation ()
  "Pop up a temporary buffer and collect the annotation."
  (cl-declare (special emacspeak-annotate-edit-buffer))
  (let ((annotation nil))
    (pop-to-buffer
     (get-buffer-create emacspeak-annotate-edit-buffer))
    (erase-buffer)
    (message "Exit recursive edit when done.")
    (recursive-edit)
    (local-set-key "\C-c\C-c" 'exit-recursive-edit)
    (setq annotation (buffer-string))
    (bury-buffer)
    annotation))
;;;###autoload
(defun emacspeak-annotate-add-annotation (&optional reset)
  "Add annotation to the annotation working buffer.
Prompt for annotation buffer if not already set.
Interactive prefix arg `reset' prompts for the annotation
buffer even if one is already set.
Annotation is entered in a temporary buffer and the
annotation is inserted into the working buffer when complete."
  (interactive "P")
  (cl-declare (special emacspeak-annotate-working-buffer))
  (when (or reset
            (null emacspeak-annotate-working-buffer))
    (setq emacspeak-annotate-working-buffer
          (get-buffer-create
           (read-buffer "Annotation working buffer: "
                        (cadr (emacspeak-annotate-make-buffer-list))))))
  (let ((annotation nil)
        (work-buffer emacspeak-annotate-working-buffer)
        (parent-buffer (current-buffer)))
    (message "Adding annotation to %s"
             emacspeak-annotate-working-buffer)
    (save-window-excursion
      (save-current-buffer
        (setq annotation
              (emacspeak-annotate-get-annotation))
        (set-buffer work-buffer)
        (insert annotation)
        (insert "\n"))
      (switch-to-buffer parent-buffer))
    (emacspeak-auditory-icon 'close-object)))

;;}}}
;;{{{ shell-toggle

;;; inspired by eshell-toggle
;;; switch to the shell buffer, and cd to the directory
;;; that is the default-directory for the previously current
;;; buffer.
;;;###autoload
(defun emacspeak-wizards-shell-toggle ()
  "Switch to the shell buffer and cd to
 the directory of the previously current buffer."
  (interactive)
  (cl-declare (special default-directory))
  (let ((dir default-directory))
    (shell)
    (unless (string-equal (expand-file-name dir)
                          (expand-file-name default-directory))
      (goto-char (point-max))
      (insert (format "pushd %s" dir))
      (comint-send-input)
      (shell-process-cd dir))
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{ pdf wizard

(defvar emacspeak-wizards-pdf-to-text-program
  "pdftotext"
  "Command for running pdftotext.")

(defcustom emacspeak-wizards-pdf-to-text-options
  "-layout"
  "options to Command for running pdftotext."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Options" "-layout"))
  :group 'emacspeak-wizards)


(defun emacspeak-wizards-pdf-open (filename &optional ask-pwd)
  "Open pdf file as text.
Optional interactive prefix arg ask-pwd prompts for password."
  (interactive
   (list
    (let ((completion-ignored-extensions nil))
      (expand-file-name
       (read-file-name
        "PDF File: "
        nil default-directory
        t nil)))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-pdf-to-text-options
                       emacspeak-wizards-pdf-to-text-program))
  (cl-assert (string-match ".pdf$"filename) t "Not a PDF file.")
  (let ((passwd (when ask-pwd (read-passwd "User Password:")))
        (output-buffer
         (format "%s"
                 (file-name-sans-extension (file-name-nondirectory filename)))))
    (shell-command
     (format
      "%s %s %s  %s - | cat -s "
      emacspeak-wizards-pdf-to-text-program
      emacspeak-wizards-pdf-to-text-options
      (if passwd
          (format "-upw %s" passwd)
        "")
      (shell-quote-argument
       (expand-file-name filename)))
     output-buffer)
    (switch-to-buffer output-buffer)
    (set-buffer-modified-p nil)
    (emacspeak-speak-mode-line)
    (emacspeak-auditory-icon 'open-object)))

;;}}}
;;{{{ find wizard

(define-derived-mode emacspeak-wizards-finder-mode special-mode
  "Emacspeak Finder"
  "Emacspeak Finder\n\n")

(defcustom emacspeak-wizards-find-switches-widget
  '(cons :tag "Find Expression"
         (menu-choice :tag "Find"
                      (string :tag "Test")
                      (const "-name")
                      (const "-iname")
                      (const "-path")
                      (const "-ipath")
                      (const "-regexp")
                      (const "-iregexp")
                      (const "-exec")
                      (const "-ok")
                      (const "-newer")
                      (const "-anewer")
                      (const "-cnewer")
                      (const "-used")
                      (const "-user")
                      (const "-uid")
                      (const "-nouser")
                      (const "-nogroup")
                      (const "-perm")
                      (const "-fstype")
                      (const "-lname")
                      (const "-ilname")
                      (const "-empty")
                      (const "-prune")
                      (const "-or")
                      (const "-not")
                      (const "-inum")
                      (const "-atime")
                      (const "-ctime")
                      (const "-mtime")
                      (const "-amin")
                      (const "-mmin")
                      (const "-cmin")
                      (const "-size")
                      (const "-type")
                      (const "-maxdepth")
                      (const "-mindepth")
                      (const "-mount")
                      (const "-noleaf")
                      (const "-xdev"))
         (string :tag "Value"))
  "Widget to get find switch."
  :type 'sexp
  :group 'emacspeak-wizards)

(defvar-local emacspeak-wizards-finder-args nil
  "List of switches to use as test arguments to find.")

(defcustom emacspeak-wizards-find-switches-that-need-quoting
  (list "-name" "-iname"
        "-path" "-ipath"
        "-regexp" "-iregexp")
  "Find switches whose args need quoting."
  :type '(repeat
          (string))
  :group 'emacspeak-wizards)

(defun emacspeak-wizards-find-quote-arg-if-necessary (switch arg)
  "Quote find arg if necessary."
  (cl-declare (special emacspeak-wizards-find-switches-that-need-quoting))
  (if (member switch emacspeak-wizards-find-switches-that-need-quoting)
      (format "'%s'" arg)
    arg))
;;;###autoload
(defun emacspeak-wizards-generate-finder ()
  "Generate a widget-enabled finder wizard."
  (interactive)
  (cl-declare (special default-directory
                       emacspeak-wizards-find-switches-widget))
  (require 'cus-edit)
  (let ((value nil)
        (notify (emacspeak-wizards-generate-finder-callback))
        (buffer-name "*Emacspeak Finder*")
        (buffer nil)
        (inhibit-read-only t))
    (when (get-buffer buffer-name) (kill-buffer buffer-name))
    (setq buffer (get-buffer-create buffer-name))
    (save-current-buffer
      (set-buffer buffer)
      (widget-insert "\n")
      (widget-insert "Emacspeak Finder\n\n")
      (widget-create 'repeat
                     :help-echo "Find Criteria"
                     :tag "Find Criteria"
                     :value value
                     :notify notify
                     emacspeak-wizards-find-switches-widget)
      (widget-insert "\n")
      (widget-create 'push-button
                     :tag "Find Matching Files"
                     :notify
                     #'(lambda (&rest _ignore)
                         (call-interactively
                          'emacspeak-wizards-finder-find)))
      (widget-create 'info-link
                     :tag "Help"
                     :help-echo "Read the online help."
                     "(find)Finding Files")
      (widget-insert "\n\n")
      (emacspeak-wizards-finder-mode)
      (use-local-map widget-keymap)
      (widget-setup)
      (local-set-key "\M-s" 'emacspeak-wizards-finder-find)
      (goto-char (point-min)))
    (pop-to-buffer buffer)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

(defun emacspeak-wizards-generate-finder-callback ()
  "Generate a callback for use in the Emacspeak Finder."
  '(lambda (widget &rest ignore)
     (cl-declare (special emacspeak-wizards-finder-args))
     (let ((value (widget-value widget)))
       (setq emacspeak-wizards-finder-args value))))
;;;###autoload
(defun emacspeak-wizards-finder-find (directory)
  "Run find-dired on specified switches after prompting for the
directory to where find is to be launched."
  (interactive
   (list
    (file-name-directory (read-file-name "Directory:"))))
  (cl-declare (special emacspeak-wizards-finder-args))
  (let ((find-args
         (mapconcat
          #'(lambda (pair)
              (format "%s %s"
                      (car pair)
                      (if (cdr pair)
                          (emacspeak-wizards-find-quote-arg-if-necessary
                           (car pair)
                           (cdr pair))
                        "")))
          emacspeak-wizards-finder-args
          " ")))
    (find-dired directory find-args)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-line)))

;;}}}
;;{{{ customize emacspeak
(declare-function emacspeak-custom-goto-group "emacspeak-custom" nil)

;;;###autoload
(defun emacspeak-customize ()
  "Customize Emacspeak."
  (interactive)
  (customize-group 'emacspeak)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-custom-goto-group))

;;}}}
;;{{{ squeeze blank lines in current buffer:
;;;###autoload
(defun emacspeak-wizards-squeeze-blanks (start end)
  "Squeeze multiple blank lines in current buffer."
  (interactive "r")
  (shell-command-on-region start end
                           "cat -s"
                           (current-buffer)
                           'replace)
  (indent-region (point-min) (point-max))
  (untabify (point-min) (point-max))
  (delete-trailing-whitespace))

;;}}}
;;{{{  count slides in region: (LaTeX specific.
;;;###autoload
(defun emacspeak-wizards-count-slides-in-region (start end)
  "Count slides starting from point."
  (interactive "r")
  (how-many "begin\\({slide}\\|{part}\\)"
            start end 'interactive))

;;}}}
;;{{{  file specific  headers via occur

(defvar emacspeak-occur-pattern nil
  "Regexp pattern used to identify header lines by command
emacspeak-wizards-occur-header-lines.")
(make-variable-buffer-local 'emacspeak-occur-pattern)
;;;###autoload
(defun emacspeak-wizards-how-many-matches (start end &optional prefix)
  "If you define a file local variable
called `emacspeak-occur-pattern' that holds a regular expression
that matches  lines of interest, you can use this command to conveniently
run `how-many' to count  matching header lines.
With interactive prefix arg, prompts for and remembers the file local pattern."
  (interactive
   (list
    (point)
    (mark)
    current-prefix-arg))
  (cl-declare (special emacspeak-occur-pattern))
  (cond
   ((and (not prefix)
         (boundp 'emacspeak-occur-pattern)
         emacspeak-occur-pattern)
    (how-many emacspeak-occur-pattern start end 'interactive))
   (t
    (let ((pattern (read-from-minibuffer "Regular expression: ")))
      (setq emacspeak-occur-pattern pattern)
      (how-many pattern start end 'interactive)))))

;;;###autoload
(defun emacspeak-wizards-occur-header-lines (&optional prefix)
  "If you define a file local variable called
`emacspeak-occur-pattern' that holds a regular expression that
matches header lines, you can use this command to conveniently
run `occur' to find matching header lines. With prefix arg,
prompts for and sets value of the file local pattern."
  (interactive "P")
  (cl-declare (special emacspeak-occur-pattern))
  (cond
   ((and (not prefix)
         (boundp 'emacspeak-occur-pattern)
         emacspeak-occur-pattern)
    (occur emacspeak-occur-pattern)
    (message "Displayed header lines in other window.")
    (emacspeak-auditory-icon 'open-object))
   (t
    (let ((pattern (read-from-minibuffer "Regular expression: ")))
      (setq emacspeak-occur-pattern pattern)
      (occur pattern)))))

;;}}}
;;{{{   Switching buffers, killing buffers etc

;;;###autoload
(defun emacspeak-kill-buffer-quietly ()
  "Kill current buffer without asking for confirmation."
  (interactive)
  (kill-buffer nil)
  (when (called-interactively-p 'interactive)
    (emacspeak-auditory-icon 'close-object)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{  spotting words

(defcustom emacspeak-wizards-spot-words-extension ".tex"
  "Default file extension  used when spotting words."
  :type 'string
  :group 'emacspeak-wizards)

(defun emacspeak-wizards-spot-words (ext word)
  "Searches recursively in all files with extension `ext'
for `word' and displays hits in a compilation buffer."
  (interactive
   (list
    (read-from-minibuffer "Extension: "
                          emacspeak-wizards-spot-words-extension)
    (read-from-minibuffer "Word: "
                          (thing-at-point 'word))))
  (cl-declare (special emacspeak-wizards-spot-words-extension))
  (compile
   (format
    "find . -type f -name '*%s' -print0 | xargs -0 -e grep -n -e \"\\b%s\\b\" "
    ext word))
  (setq emacspeak-wizards-spot-words-extension ext)
  (emacspeak-auditory-icon 'task-done))
;;;###autoload
(defun emacspeak-wizards-fix-typo (ext word correction)
  "Search and replace  recursively in all files with extension `ext'
for `word' and replace it with correction.
Use with caution."
  (interactive
   (list
    (read-from-minibuffer "Extension: "
                          emacspeak-wizards-spot-words-extension)
    (read-from-minibuffer "Word: "
                          (thing-at-point 'word))
    (read-from-minibuffer "Correction: "
                          (thing-at-point 'word))))
  (cl-declare (special emacspeak-wizards-spot-words-extension))
  (compile
   (format
    "find . -type f -name '*%s' -print0 \
| xargs -0 -e  perl -pi -e \'s/%s/%s/g' "
    ext word correction))
  (setq emacspeak-wizards-spot-words-extension ext)
  (emacspeak-auditory-icon 'task-done))

;;}}}
;;{{{ pod -- perl online docs
(declare-function cperl-pod2man-build-command "cperl-mode" nil)

(defun emacspeak-wizards-display-pod-as-manpage (filename)
  "Create a virtual manpage in Emacs from the Perl Online Documentation."
  (interactive
   (list
    (expand-file-name
     (read-file-name "Enter name of POD file: "))))
  (cl-declare (special pod2man-program))
  (require 'man)
  (let* ((pod2man-args (concat filename " | nroff -man "))
         (bufname (concat "Man " filename))
         (buffer (generate-new-buffer bufname)))
    (save-current-buffer
      (set-buffer buffer)
      (let ((process-environment (copy-sequence process-environment)))
        ;; Prevent any attempt to use display terminal fanciness.
        (setenv "TERM" "dumb")
        (set-process-sentinel
         (start-process pod2man-program buffer "sh" "-c"
                        (format (cperl-pod2man-build-command) pod2man-args))
         'Man-bgproc-sentinel)))))

;;}}}
;;{{{ fix text that has gotten read-only accidentally

(defun emacspeak-wizards-fix-read-only-text (start end)
  "Nuke read-only property on text range."
  (interactive "r")
  (let ((inhibit-read-only t))
    (put-text-property start end
                       'read-only nil)))

;;}}}
;;{{{ VC viewer
(defcustom emacspeak-wizards-vc-viewer-command
  "setterm -dump %s -file %s"
  "Command line for dumping out virtual console.  Make sure you have
access to /dev/vcs* by adding yourself to the appropriate group.  On
Ubuntu and Debian this is group `tty'."
  :type 'string
  :group 'emacspeak-wizards)

(define-derived-mode emacspeak-wizards-vc-view-mode special-mode
  "VC Viewer  Interaction"
  "Major mode for interactively viewing virtual console contents.\n\n
\\{emacspeak-wizards-vc-view-mode-map}")

(defvar emacspeak-wizards-vc-console nil
  "Buffer local value specifying console we are viewing.")

(make-variable-buffer-local 'emacspeak-wizards-vc-console)

;;;###autoload
(defun emacspeak-wizards-vc-viewer (console)
  "View contents of specified virtual console."
  (interactive "nConsole:")
  (cl-declare (special emacspeak-wizards-vc-viewer-command
                       emacspeak-wizards-vc-console
                       temporary-file-directory))
  (ems-with-messages-silenced
   (let ((command
          (format emacspeak-wizards-vc-viewer-command
                  console
                  (expand-file-name
                   (format "vc-%s.dump" console)
                   temporary-file-directory)))
         (buffer (get-buffer-create
                  (format "*vc-%s*" console))))
     (shell-command command buffer)
     (switch-to-buffer buffer)
     (kill-all-local-variables)
     (insert-file-contents
      (expand-file-name
       (format "vc-%s.dump" console)
       temporary-file-directory))
     (set-buffer-modified-p nil)
     (emacspeak-wizards-vc-view-mode)
     (setq emacspeak-wizards-vc-console console)
     (goto-char (point-min))
     (when (called-interactively-p 'interactive) (emacspeak-speak-line)))))


(defun emacspeak-wizards-vc-viewer-refresh ()
  "Refresh view of VC we're viewing."
  (interactive)
  (cl-declare (special emacspeak-wizards-vc-console))
  (unless (eq major-mode
              'emacspeak-wizards-vc-view-mode)
    (error "Not viewing a virtual console."))
  (let ((console emacspeak-wizards-vc-console)
        (command
         (format emacspeak-wizards-vc-viewer-command
                 emacspeak-wizards-vc-console
                 (expand-file-name
                  (format "vc-%s.dump"
                          emacspeak-wizards-vc-console)
                  temporary-file-directory)))
        (inhibit-read-only t)
        (orig (point)))
    (shell-command command)
    (fundamental-mode)
    (erase-buffer)
    (insert-file-contents
     (expand-file-name
      (format "vc-%s.dump"
              console)
      temporary-file-directory))
    (set-buffer-modified-p nil)
    (goto-char orig)
    (emacspeak-wizards-vc-view-mode)
    (setq emacspeak-wizards-vc-console console)
    (when (called-interactively-p 'interactive)
      (emacspeak-speak-line))))

;;;###autoload
(defun emacspeak-wizards-vc-n ()
  "Accelerator for VC viewer."
  (interactive)
  (cl-declare (special last-input-event))
  (emacspeak-wizards-vc-viewer (format "%c" last-input-event))
  (emacspeak-speak-line)
  (emacspeak-auditory-icon 'open-object))

(cl-declaim (special emacspeak-wizards-vc-view-mode-map))

(define-key emacspeak-wizards-vc-view-mode-map
  "\C-l" 'emacspeak-wizards-vc-viewer-refresh)

;;}}}
;;{{{ google Transcoder

;;}}}
;;{{{ longest line in region
;;;###autoload
(defun emacspeak-wizards-find-longest-line-in-region (start end)
  "Find longest line in region.
Moves to the longest line when called interactively."
  (interactive "r")
  (let ((max 0)
        (where nil))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (when
            (< max
               (- (line-end-position)
                  (line-beginning-position)))
          (setq max (- (line-end-position)
                       (line-beginning-position)))
          (setq where (line-beginning-position)))
        (forward-line 1)))
    (when (called-interactively-p 'interactive)
      (message "Longest line is %s columns"
               max)
      (goto-char where))
    max))

(defun emacspeak-wizards-find-shortest-line-in-region (start end)
  "Find shortest line in region.
Moves to the shortest line when called interactively."
  (interactive "r")
  (let ((min 1)
        (where (point)))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (when
            (< (- (line-end-position)
                  (line-beginning-position))
               min)
          (setq min (- (line-end-position)
                       (line-beginning-position)))
          (setq where (line-beginning-position)))
        (forward-line 1)))
    (when (called-interactively-p 'interactive)
      (message "Shortest line is %s columns"
               min)
      (goto-char where))
    min))

;;}}}
;;{{{ longest para in region
;;;###autoload
(defun emacspeak-wizards-find-longest-paragraph-in-region (start end)
  "Find longest paragraph in region.
Moves to the longest paragraph when called interactively."
  (interactive "r")
  (let ((max 0)
        (where nil)
        (para-start start))
    (save-excursion
      (goto-char start)
      (while (and (not (eobp))
                  (< (point) end))
        (forward-paragraph 1)
        (when
            (< max (- (point) para-start))
          (setq max (- (point) para-start))
          (setq where para-start))
        (setq para-start (point))))
    (when (called-interactively-p 'interactive)
      (message "Longest paragraph is %s characters"
               max)
      (goto-char where))
    max))

;;}}}
;;{{{ find grep using compile

;;;###autoload
(defun emacspeak-wizards-find-grep (glob pattern)
  "Run compile using find and grep.
Interactive  arguments specify filename pattern and search pattern."
  (interactive
   (list
    (read-from-minibuffer "Look in files: ")
    (read-from-minibuffer "Look for: ")))
  (compile
   (format
    "find . -type f -name '%s' -print0 | xargs -0 -e grep -n -e '%s'"
    glob pattern))
  (emacspeak-auditory-icon 'task-done))

;;}}}
;;{{{ face wizard
;;;###autoload
(defun emacspeak-wizards-show-face (face)
  "Show salient properties of specified face."
  (interactive
   (list
    (read-face-name "Face")))
  (let ((output (get-buffer-create "*emacspeak-face-display*")))
    (save-current-buffer
      (set-buffer output)
      (setq buffer-read-only nil)
      (erase-buffer)
      (insert (format "Face: %s\n" face))
      (cl-loop for a in
               (mapcar #'car face-attribute-name-alist)
               do
               (unless (eq 'unspecified (face-attribute face a))
                 (insert
                  (format "%s\t%s\n"
                          a
                          (face-attribute face a)))))
      (insert
       (format "Documentation: %s\n"
               (face-documentation face)))
      (setq buffer-read-only t))
    (when (called-interactively-p 'interactive)
      (switch-to-buffer output)
      (goto-char (point-min))
      (emacspeak-speak-mode-line)
      (emacspeak-auditory-icon 'open-object))))

;;}}}
;;{{{ voice sample


(defun emacspeak-wizards-voice-sampler (personality)
  "Read a personality  and apply it to the current line."
  (interactive (list (voice-setup-read-personality)))
  (put-text-property (line-beginning-position) (line-end-position)
                     'personality personality)
  (emacspeak-speak-line))


(defun emacspeak-wizards-generate-voice-sampler (step)
  "Generate a buffer that shows a sample line in all the ACSS settings
for the current voice family."
  (interactive "nStep:")
  (let ((buffer (get-buffer-create "*Voice Sampler*"))
        (voice nil))
    (save-current-buffer
      (set-buffer buffer)
      (erase-buffer)
      (cl-loop
       for a from 0 to 9 by step do
       (cl-loop
        for p from 0 to 9 by step do
        (cl-loop
         for s from 0 to 9 by step do
         (cl-loop
          for r from 0 to 9 by step do
          (setq voice (voice-setup-personality-from-style
                       (list nil a p s r)))
          (insert
           (format
            " Aural CSS average-pitch %s pitch-range %s stress %s richness %s"
            a p s r))
          (put-text-property (line-beginning-position)
                             (line-end-position)
                             'personality voice)
          (end-of-line)
          (insert "\n"))))))
    (switch-to-buffer buffer)
    (goto-char (point-min))))


(defun emacspeak-wizards-show-defined-voices ()
  "Display a buffer with sample text in the defined voices."
  (interactive)
  (let ((buffer (get-buffer-create "*Voice Sampler*"))
        (voices
         (sort
          (voice-setup-defined-voices)
          #'(lambda (a b)
              (string-lessp (symbol-name a) (symbol-name b))))))
    (save-current-buffer
      (set-buffer buffer)
      (erase-buffer)
      (cl-loop
       for v in voices do
       (insert
        (format "This is a sample of voice %s. " (symbol-name v)))
       (put-text-property
        (line-beginning-position) (line-end-position)
        'personality v)
       (end-of-line)
       (insert "\n")))
    (funcall-interactively #'switch-to-buffer buffer)
    (goto-char (point-min))))

;;}}}
;;{{{ list-voices-display

(defvar ems--wizards-sampler-text
  "Emacspeak --- The Complete Audio Desktop!"
  "Sample text used  when displaying available voices.")

(defun emacspeak-wizards-list-voices (pattern)
  "Show all defined voice-face mappings  in a help buffer.
Sample text to use comes from variable
  `ems--wizards-sampler-text "
  (interactive (list (and current-prefix-arg
                          (read-string "List faces matching regexp: "))))
  (cl-declare (special ems--wizards-sampler-text))
  (let ((list-faces-sample-text ems--wizards-sampler-text))
    (list-faces-display pattern)
    (message "Displayed voice-face mappings in other window.")))

;;}}}
;;{{{ tramp wizard
(defcustom emacspeak-wizards-tramp-locations nil
  "Tramp locations used by Emacspeak tramp wizard.
Locations added here via custom can be opened using command
emacspeak-wizards-tramp-open-location
bound to \\[emacspeak-wizards-tramp-open-location]."
  :type '(repeat
          (cons :tag "Tramp"
                (string :tag "Name")
                (string :tag "Location")))
  :group 'emacspeak-wizards)


(defun emacspeak-wizards-tramp-open-location (name)
  "Open specified tramp location.
Location is specified by name."
  (interactive
   (list
    (let ((completion-ignore-case t))
      (completing-read "Location:"
                       emacspeak-wizards-tramp-locations
                       nil 'must-match))))
  (cl-declare (special emacspeak-wizards-tramp-locations))
  (let ((location (cdr (assoc name
                              emacspeak-wizards-tramp-locations))))
    (find-file
     (read-file-name "Open: " location))))

;;}}}
;;{{{ ISO dates
;;; implementation based on icalendar.el

;;;###autoload
(defun emacspeak-wizards-speak-iso-datetime (iso)
  "Make ISO date-time speech friendly."
  (interactive
   (list
    (read-from-minibuffer "ISO DateTime:"
                          (word-at-point))))
  (ems-with-messages-silenced
   (let ((time (emacspeak-speak-decode-iso-datetime iso)))
     (tts-with-punctuations 'some (dtk-speak time))
     (message time))))

;;}}}
;;{{{ date pronouncer wizard
(defvar emacspeak-wizards-mm-dd-yyyy-date-pronounce nil
  "Toggled by wizard to record how we are pronouncing mm-dd-yyyy
dates.")

;;;###autoload
(defun emacspeak-wizards-toggle-mm-dd-yyyy-date-pronouncer ()
  "Toggle pronunciation of mm-dd-yyyy dates."
  (interactive)
  (cl-declare (special emacspeak-wizards-mm-dd-yyyy-date-pronounce
                       emacspeak-pronounce-date-mm-dd-yyyy-pattern))
  (cond
   (emacspeak-wizards-mm-dd-yyyy-date-pronounce
    (setq emacspeak-wizards-mm-dd-yyyy-date-pronounce nil)
    (emacspeak-pronounce-remove-buffer-local-dictionary-entry
     emacspeak-pronounce-date-mm-dd-yyyy-pattern))
   (t (setq emacspeak-wizards-mm-dd-yyyy-date-pronounce t)
      (emacspeak-pronounce-add-buffer-local-dictionary-entry
       emacspeak-pronounce-date-mm-dd-yyyy-pattern
       (cons 're-search-forward
             'emacspeak-pronounce-mm-dd-yyyy-date))))
  (message "Will %s pronounce mm-dd-yyyy date strings in
  English."
           (if emacspeak-wizards-mm-dd-yyyy-date-pronounce "" "
  not ")))

(defvar emacspeak-wizards-yyyymmdd-date-pronounce nil
  "Toggled by wizard to record how we are pronouncing yyyymmdd dates.")

;;;###autoload
(defun emacspeak-wizards-toggle-yyyymmdd-date-pronouncer ()
  "Toggle pronunciation of yyyymmdd  dates."
  (interactive)
  (cl-declare (special emacspeak-wizards-yyyymmdd-date-pronounce
                       emacspeak-pronounce-date-yyyymmdd-pattern))
  (cond
   (emacspeak-wizards-yyyymmdd-date-pronounce
    (setq emacspeak-wizards-yyyymmdd-date-pronounce nil)
    (emacspeak-pronounce-remove-buffer-local-dictionary-entry
     emacspeak-pronounce-date-yyyymmdd-pattern))
   (t (setq emacspeak-wizards-yyyymmdd-date-pronounce t)
      (emacspeak-pronounce-add-buffer-local-dictionary-entry
       emacspeak-pronounce-date-yyyymmdd-pattern
       (cons 're-search-forward
             'emacspeak-pronounce-yyyymmdd-date))))
  (message "Will %s pronounce YYYYMMDD date strings in
  English."
           (if emacspeak-wizards-yyyymmdd-date-pronounce "" "
  not ")))

;;}}}
;;{{{ units wizard

;;;###autoload
(defun emacspeak-wizards-units ()
  "Run units in a comint sub-process."
  (interactive)
  (let ((process-environment '("PAGER=cat")))
    (make-comint "units" "units"
                 nil "--verbose"))
  (switch-to-buffer "*units*")
  (emacspeak-auditory-icon 'select-object)
  (goto-char (point-max))
  (unless emacspeak-comint-autospeak
    (emacspeak-toggle-comint-autospeak))
  (emacspeak-speak-mode-line))

;;}}}
;;{{{ shell history:


(defun emacspeak-wizards-shell-bind-keys ()
  "Set up additional shell mode keys."
  (cl-loop for b in
           '(
             ("\C-ch" emacspeak-wizards-refresh-shell-history)
             ("\C-cr" comint-redirect-send-command))
           do
           (define-key shell-mode-map (cl-first b) (cl-second b))))

;;}}}
;;{{{ Organizing Shells: next, previous, tag

(defun ems--shell-pushd-if-needed (dir target)
  "Helper: execute pushd in shell `target' if needed."
  (with-current-buffer target
    (unless (string= (expand-file-name dir) default-directory)
      (goto-char (point-max))
      (insert (format "pushd %s" dir))
      (comint-send-input)
      (shell-process-pushd dir))))

(defun emacspeak-wizards-get-shells ()
  "Return list of shell buffers."
  (cl-loop
   for b in (buffer-list)
   when (with-current-buffer b (eq major-mode 'shell-mode)) collect b))

(defun emacspeak-wizards-switch-shell (direction)
  "Switch to next/previous shell buffer.
Direction specifies previous/next."
  (let* ((shells (emacspeak-wizards-get-shells))
         (target nil))
    (cond
     ((> (length shells) 1)
      (when (> direction 0) (bury-buffer))
      (setq target
            (if (> direction 0)
                (cl-second shells)
              (nth (1- (length shells)) shells)))
      (funcall-interactively #'pop-to-buffer target))
     ((= 1 (length shells)) (shell "1-shell"))
     (t (call-interactively #'shell)))))

;;;###autoload
(defun emacspeak-wizards-shell (&optional prefix)
  "Run Emacs built-in `shell' command when not in a shell buffer, or
when called with a prefix argument. When called from a shell buffer,
switches to `next' shell buffer. When called from outside a shell
buffer, find the most `appropriate shell' and switch to it. Once
switched, set default directory in that target shell to the directory
of the source buffer."
  (interactive "P")
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (cond
   ((or prefix (not (eq major-mode 'shell-mode)))
    (let ((dir default-directory)
          (shells (emacspeak-wizards-get-shells))
          (target nil)
          (target-len 0))
      (cl-loop
       for s in shells do
       (let ((sd
              (with-current-buffer s
                (expand-file-name emacspeak-wizards--project-shell-directory))))
         (when
             (and
              (string-prefix-p sd dir)
              (> (length sd) target-len))
           (setq target s)
           (setq target-len (length sd)))))
      (cond
       (target (funcall-interactively #'pop-to-buffer target)
               (ems--shell-pushd-if-needed dir target))
       (t (call-interactively #'shell)))))
   (t (call-interactively 'emacspeak-wizards-next-shell))))

;;; Inspired by package project-shells from melpa --- but simplified.

(defvar emacspeak-wizards--shells-table (make-hash-table :test #'eq)
  "Table mapping live shell buffers to keys.")

(defun emacspeak-wizards--build-shells-table ()
  "Populate hash-table with live shell buffers."
  (cl-declare (special emacspeak-wizards--shells-table))
;;; First, remove dead buffers
  (cl-loop
   for k being the hash-keys of emacspeak-wizards--shells-table
   unless (buffer-live-p (gethash k emacspeak-wizards--shells-table))
   do (remhash k emacspeak-wizards--shells-table))
  (let ((shells (emacspeak-wizards-get-shells))
        (v (hash-table-values emacspeak-wizards--shells-table)))
;;; Add in live shells that are new
    (mapc
     #'(lambda (s)
         (when (not (memq s v))
           (puthash
            (hash-table-count emacspeak-wizards--shells-table)
            s emacspeak-wizards--shells-table)))
     shells)))

;;;###autoload
(defun emacspeak-wizards-shell-by-key (&optional prefix)
  "Switch to shell buffer by key. This provides a predictable
  means for switching to a specific shell buffer. When invoked
  from a non-shell-mode buffer that is a dired-buffer or is
  visiting a file, invokes `cd ' in the shell to change to the
  value of `default-directory' --- if called with a
  prefix-arg. When already in a shell buffer, interactive prefix
  arg `prefix' causes this shell to be re-keyed if appropriate
  --- see \\[emacspeak-wizards-shell-re-key] for an explanation
  of how re-keying works."
  (interactive "P")
  (cl-declare (special last-input-event emacspeak-wizards--shells-table
                       major-mode default-directory))
  (unless (emacspeak-wizards-get-shells) (shell))
  (emacspeak-wizards--build-shells-table)
  (cond
   ((and prefix (eq major-mode 'shell-mode))
    (emacspeak-wizards-shell-re-key
     (read (format "%c" last-input-event))
     (current-buffer)))
   (t
    (let* ((directory default-directory)
           (key
            (%
             (read (format "%c" last-input-event))
             (length (hash-table-keys emacspeak-wizards--shells-table))))
           (buffer (gethash key emacspeak-wizards--shells-table)))
      (when
          (and prefix
               (or (eq major-mode 'dired-mode) buffer-file-name)) ;  source determines target directory
        (ems--shell-pushd-if-needed directory buffer))
      (funcall-interactively #'pop-to-buffer buffer)))))

(defcustom emacspeak-wizards-project-shells nil
  "List of shell-name/initial-directory pairs."
  :type '(repeat
          (list
           (string :tag "Buffer Name")
           (directory :tag "Directory")))
  :group 'emacspeak-wizards)

(defvar-local emacspeak-wizards--project-shell-directory "~/"
  "Default directory for a given project shell.")

;;;###autoload
(defun emacspeak-wizards-project-shells-initialize ()
  "Create shells per `emacspeak-wizards-project-shells'."
  (cl-declare (special emacspeak-wizards-project-shells))
  (unless emacspeak-wizards-project-shells (shell))
  (cl-loop
   for pair in (reverse emacspeak-wizards-project-shells) do
   (let* ((name (cl-first pair))
          (dir (cl-second pair))
          (default-directory dir))
     (with-current-buffer (shell name)
       (setq emacspeak-wizards--project-shell-directory dir))))
     (emacspeak-wizards--build-shells-table))


(defun emacspeak-wizards-shell-directory-set ()
  "Define current directory as this shell's project directory."
  (interactive)
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (setq emacspeak-wizards--project-shell-directory default-directory)
  (emacspeak-auditory-icon 'task-done)
  (message (abbreviate-file-name default-directory)))

;;;###autoload
(defun emacspeak-wizards-shell-directory-reset ()
  "Set current directory to this shell's initial directory if one was defined."
  (interactive)
  (cl-declare (special emacspeak-wizards--project-shell-directory))
  (ems--shell-pushd-if-needed
   emacspeak-wizards--project-shell-directory (current-buffer))
  (emacspeak-auditory-icon 'task-done)
  (message (abbreviate-file-name default-directory)))

(defun emacspeak-wizards-shell-re-key (key buffer)
  "Re-key shell-buffer `buffer' to be accessed via key `key'. The old shell
buffer keyed by `key'gets the key of buffer `buffer'."
  (cl-declare (special emacspeak-wizards--shells-table
                       emacspeak-wizards--project-shell-directory))
  (cond
   ((eq buffer (gethash key emacspeak-wizards--shells-table))
    (message "Rekey: Nothing to do"))
   (t
    (setq key ;;; works as a circular list
          (% key (length (hash-table-keys emacspeak-wizards--shells-table))))
    (let ((swap-buffer (gethash key emacspeak-wizards--shells-table))
          (swap-key nil))
      (cl-loop
       for k being the hash-keys of emacspeak-wizards--shells-table do
       (when (eq buffer (gethash k emacspeak-wizards--shells-table))
         (setq swap-key k)))
      (puthash key buffer emacspeak-wizards--shells-table)
      (when swap-key
        (puthash swap-key swap-buffer emacspeak-wizards--shells-table))
      (message "%s is now  on %s" (buffer-name buffer) key)))))

;;}}}
;;{{{ show commentary:
(defun ems-cleanup-commentary (commentary)
  "Cleanup commentary."
  (save-current-buffer
    (set-buffer (get-buffer-create " *doc-temp*"))
    (erase-buffer)
    (insert commentary)
    (goto-char (point-min))
    (flush-lines "{{{")
    (goto-char (point-min))
    (flush-lines "}}}")
    (goto-char (point-min))
    (delete-blank-lines)
    (goto-char (point-min))
    (while (re-search-forward "^;+ ?" nil t)
      (replace-match "" nil t))
    (buffer-string)))

;;}}}
;;{{{ Add autoload cookies:

(defvar emacspeak-autoload-cookie-pattern
  ";;;###autoload"
  "autoload cookie pattern.")


(defun emacspeak-wizards-add-autoload-cookies (&optional f)
  "Add autoload cookies to file f.
Default is to add autoload cookies to current file."
  (interactive)
  (cl-declare (special emacspeak-autoload-cookie-pattern))
  (or f (setq f (buffer-file-name)))
  (let ((buffer (find-file-noselect f))
        (count 0))
    (with-current-buffer buffer
      (goto-char (point-min))
      (unless (eq major-mode 'emacs-lisp-mode)
        (error "Not an Emacs Lisp file."))
      (condition-case nil
          (while (not (eobp))
            (re-search-forward "^ *(interactive")
            (beginning-of-defun)
            (forward-line -1)
            (unless (looking-at emacspeak-autoload-cookie-pattern)
              (cl-incf count)
              (forward-line 1)
              (beginning-of-line)
              (insert
               (format "%s\n" emacspeak-autoload-cookie-pattern)))
            (end-of-defun))
        (error "Added %d autoload cookies." count)))))

;;}}}
;;{{{ Bullet navigation


(defun emacspeak-wizards-next-bullet ()
  "Navigate to and speak next `bullet'."
  (interactive)
  (search-forward-regexp
   "\\(^ *[0-9]+\\. \\)\\|\\( O \\) *")
  (emacspeak-auditory-icon 'item)
  (emacspeak-speak-line))

(defun emacspeak-wizards-previous-bullet ()
  "Navigate to and speak previous `bullet'."
  (interactive)
  (search-backward-regexp
   "\\(^ *[0-9]+\. \\)\\|\\(^O\s\\) *")
  (emacspeak-auditory-icon 'item)
  (emacspeak-speak-line))

;;}}}
;;{{{ Braille

;;;###autoload
(defun emacspeak-wizards-braille (s)
  "Insert Braille string at point."
  (interactive "sBraille: ")
  (require 'toy-braille)
  (insert (get-toy-braille-string s))
  (emacspeak-auditory-icon 'yank-object)
  (message "Brailled %s" s))

;;}}}
;;{{{  Buffer Cycling:
(defun emacspeak-wizards-buffer-cycle-previous (mode)
  "Return previous  buffer in cycle order having same major mode as `mode'."
  (catch 'cl-loop
    (dolist (buf (reverse (cdr (buffer-list (selected-frame)))))
      (when (with-current-buffer buf (eq mode major-mode))
        (throw 'cl-loop buf)))))

(defun emacspeak-wizards-buffer-cycle-next (mode)
  "Return next buffer in cycle order having same major mode as `mode'."
  (catch 'cl-loop
    (dolist (buf (cdr (buffer-list (selected-frame))))
      (when (with-current-buffer buf (eq mode major-mode))
        (throw 'cl-loop buf)))))
;;;###autoload
(defun emacspeak-wizards-cycle-to-previous-buffer ()
  "Cycles to previous buffer having same mode."
  (interactive)
  (let ((prev (emacspeak-wizards-buffer-cycle-previous major-mode)))
    (cond
     (prev
      (funcall-interactively #'pop-to-buffer prev))
     (t (error "No previous buffer in mode %s" major-mode)))))

;;;###autoload
(defun emacspeak-wizards-cycle-to-next-buffer ()
  "Cycles to next buffer having same mode."
  (interactive)
  (let ((next (emacspeak-wizards-buffer-cycle-next major-mode)))
    (cond
     (next (bury-buffer)
           (funcall-interactively #'pop-to-buffer next))
     (t (error "No next buffer in mode %s" major-mode)))))

;;}}}
;;{{{ Start or switch to term:

;;;###autoload
(defun emacspeak-wizards-term (create)
  "Switch to an ansi-term buffer or create one.
With prefix arg, always creates a new terminal.
Otherwise cycles through existing terminals, creating the first
term if needed."
  (interactive "P")
  (cl-declare (special explicit-shell-file-name))
  (let ((next (or create (emacspeak-wizards-buffer-cycle-next 'term-mode))))
    (cond
     ((or create (not next)) (ansi-term explicit-shell-file-name))
     (next
      (when (derived-mode-p 'term-mode) (bury-buffer))
      (switch-to-buffer next))
     (t (error "Confused?")))
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{ Espeak: MultiLingual Wizard

(defvar emacspeak-wizards-espeak-voices-alist nil
  "Association list of ESpeak voices to voice codes.")

(defun emacspeak-wizards-espeak-build-voice-table ()
  "Build up alist of espeak voices."
  (cl-declare (special emacspeak-wizards-espeak-voices-alist))
  (with-temp-buffer
    (shell-command "espeak-ng  --voices" (current-buffer))
    (goto-char (point-min))
    (forward-line 1)
    (while (not (eobp))
      (let ((fields
             (split-string
              (buffer-substring
               (line-beginning-position) (line-end-position)))))
        (push (cons (cl-fourth fields) (cl-second fields))
              emacspeak-wizards-espeak-voices-alist))
      (forward-line 1))))

(defun emacspeak-wizards-espeak-get-voice-code ()
  "Read and return ESpeak voice code with completion."
  (cl-declare (special emacspeak-wizards-espeak-voices-alist))
  (or emacspeak-wizards-espeak-voices-alist
      (emacspeak-wizards-espeak-build-voice-table))
  (let ((completion-ignore-case t))
    (cdr
     (assoc
      (completing-read "Lang:"
                       emacspeak-wizards-espeak-voices-alist)
      emacspeak-wizards-espeak-voices-alist))))

;;;###autoload
(defun emacspeak-wizards-espeak-string (string)
  "Speak string in lang via ESpeak.
Lang is obtained from property `lang' on string, or  via an interactive prompt."
  (interactive "sString: ")
  (let ((lang (get-text-property 0 'lang string)))
    (unless lang
      (setq lang
            (cond
             ((called-interactively-p 'interactive)
              (emacspeak-wizards-espeak-get-voice-code))
             (t "en"))))
    (shell-command
     (format "espeak -v %s '%s'" lang string))))

;;;###autoload
(defun emacspeak-wizards-espeak-region (start end)
  "Speak region using ESpeak polyglot wizard."
  (interactive "r")
  (save-excursion
    (goto-char start)
    (while (< start end)
      (goto-char
       (next-single-property-change
        start 'lang
        (current-buffer) end))
      (emacspeak-wizards-espeak-string (buffer-substring start (point)))
      (skip-syntax-forward " ")
      (setq start (point)))))

;;;###autoload
(defun emacspeak-wizards-espeak-line ()
  "Speak line using espeak polyglot wizard."
  (interactive)
  (ems-with-messages-silenced
   (emacspeak-wizards-espeak-region
    (line-beginning-position) (line-end-position))))

;;}}}
;;{{{ Helper: Enumerate commands whose names  match  a pattern


(defun emacspeak-wizards-enumerate-matching-commands (pattern)
  "Return list of commands whose names match pattern."
  (interactive "sFilter Regex: ")
  (let ((result nil))
    (mapatoms
     #'(lambda (s)
         (when (and (commandp s)
                    (string-match pattern (symbol-name s)))
           (push s result))))
    result))

;;;###autoload
(defun emacspeak-wizards-enumerate-uncovered-commands (pattern &optional bound-only)
  "Enumerate unadvised commands matching pattern.
Optional interactive prefix arg `bound-only'
filters out commands that dont have an active key-binding."
  (interactive "sFilter Regex:\nP")
  (let ((result nil))
    (mapatoms
     #'(lambda (s)
         (let ((name (symbol-name s)))
           (when
               (and
                (string-match pattern name)
                (commandp s)
                (if bound-only (where-is-internal s nil nil t) t)
                (not (string-match "^emacspeak" name))
                (not (string-match "^ad-Orig" name))
                (not (ad-find-some-advice s 'any "emacspeak")))
             (push s result)))))
    (sort result
          #'(lambda (a b) (string-lessp (symbol-name a) (symbol-name b))))))

;;;###autoload
(defun emacspeak-wizards-enumerate-unmapped-faces (&optional pattern)
  "Enumerate unmapped faces matching pattern."
  (interactive "sPattern:")
  (or pattern (setq pattern "."))
  (let ((result
         (delq
          nil
          (mapcar
           #'(lambda (s)
               (let ((name (symbol-name s)))
                 (when
                     (and
                      (string-match pattern name)
                      (null (voice-setup-get-voice-for-face s)))
                   s)))
           (face-list)))))
    (sort result
          #'(lambda (a b) (string-lessp (symbol-name a) (symbol-name b))))))


(defun emacspeak-wizards-enumerate-obsolete-faces ()
  "utility function to enumerate old, obsolete maps that we have still
mapped to voices."
  (interactive)
  (delq nil
        (mapcar
         #'(lambda (face) (unless (facep face) face))
         (cl-loop for k being the hash-keys of voice-setup-face-voice-table
                  collect k))))

(defun emacspeak-wizards-enumerate-matching-faces (pattern)
  "Enumerate  faces matching pattern."
  (interactive "sPattern:")
  (let ((result
         (delq
          nil
          (mapcar
           #'(lambda (s)
               (let ((name (symbol-name s)))
                 (when (string-match pattern name) name)))
           (face-list)))))
    (sort result #'(lambda (a b) (string-lessp a b)))))

;;}}}
;;{{{Emacspeak Execute Command:

(defconst emacspeak-wizards-emacspeak-command-pattern
  (concat "^"
          (regexp-opt
           '("amixer" "cd-tool"
             "dectalk" "dtk" "espeak" "mac-"
             "emacspeak" "xbacklight"
                 "gm-" "gmap"  "gweb"
             "ladspa" "soundscape" "outloud" "sox-"   "tts" "voice-")))
  "Patterns to match Emacspeak command names.")
;;;###autoload
(defun emacspeak-wizards-execute-emacspeak-command (command)
  "Prompt for and execute an Emacspeak command."
  (interactive
   (list
    (read
     (completing-read
      "Emacspeak Command:"
      (emacspeak-wizards-enumerate-matching-commands
       emacspeak-wizards-emacspeak-command-pattern)))))
  (cl-declare (special emacspeak-wizards-emacspeak-command-pattern))
  (call-interactively command))

;;}}}
;;{{{ Shell Helper: Path Cleanup

(defun emacspeak-wizards-cleanup-shell-path ()
  "Cleans up duplicates in shell path env variable."
  (interactive)
  (let ((p (cl-delete-duplicates (parse-colon-path (getenv "PATH"))
                                 :test #'string=))
        (result nil))
    (setq result (mapconcat #'identity p ":"))
    (kill-new (format "export PATH=\"%s\"" result))
    (setenv "PATH" result)
    (message (setenv "PATH" result))))

(defun emacspeak-wizards-exec-path-from-shell ()
  "Update exec-path from shell path."
  (interactive)
  (emacspeak-wizards-cleanup-shell-path)
  (let ((dirs (split-string (getenv "PATH") ":"))
        (updated (copy-sequence exec-path)))
    (cl-loop
     for d in dirs do
     (cl-pushnew d updated))
    (setq exec-path updated)))

;;}}}
;;{{{ Run shell command on current file:

;;;###autoload
(defun emacspeak-wizards-shell-command-on-current-file (command)
  "Prompts for and runs shell command on current file."
  (interactive (list (read-shell-command "Command: ")))
  (shell-command (format "%s %s" command (buffer-file-name))))

;;}}}
;;{{{ Filtered buffer lists:
(defun emacspeak-wizards-view-buffers-filtered-by-predicate (predicate)
  "Display list of buffers filtered by specified predicate."
  (let ((buffer-list
         (cl-loop
          for b in (buffer-list)
          when (funcall predicate b) collect b))
        (buffer (get-buffer-create (format "*: Filtered Buffer Menu"))))
    (cl-assert buffer-list t "No buffers in this mode.")
    (when buffer-list
      (with-current-buffer buffer
        (Buffer-menu-mode)
        (list-buffers--refresh buffer-list)
        (tabulated-list-print))
      buffer)))


(defun emacspeak-wizards-view-buffers-filtered-by-mode (mode)
  "Display list of buffers filtered by specified mode."
  (switch-to-buffer
   (emacspeak-wizards-view-buffers-filtered-by-predicate
    #'(lambda (buffer)
        (with-current-buffer buffer
          (eq major-mode mode)))))
  (rename-buffer (format "Buffers Filtered By  %s" mode) 'unique)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-line))

;;;###autoload
(defun emacspeak-wizards-view-buffers-filtered-by-this-mode ()
  "Buffer menu filtered by  mode of current-buffer."
  (interactive)
  (emacspeak-wizards-view-buffers-filtered-by-mode major-mode))

;;;###autoload
(defun emacspeak-wizards-view-buffers-filtered-by-m-player-mode ()
  "Buffer menu filtered by  m-player mode."
  (interactive)
  (switch-to-buffer
   (emacspeak-wizards-view-buffers-filtered-by-predicate
    #'(lambda (buffer)
        (with-current-buffer buffer
          (and
           (eq major-mode 'emacspeak-m-player-mode)
           (process-live-p (get-buffer-process buffer)))))))
  (rename-buffer "*Media Player Buffers*" 'unique)
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-line))

;;;###autoload
(defun emacspeak-wizards-eww-buffer-list ()
  "Display list of open EWW buffers."
  (interactive)
  (emacspeak-wizards-view-buffers-filtered-by-mode 'eww-mode))
;;}}}
;;{{{ TuneIn:

;;;###autoload
(defun emacspeak-wizards-tune-in-radio-browse (&optional category)
  "Browse Tune-In Radio.
Optional interactive prefix arg `category' prompts for a category."
  (interactive "P")
  (require 'emacspeak-url-template)
  (let ((name (if category "RadioTime Categories" "RadioTime Browser")))
    (emacspeak-url-template-open (emacspeak-url-template-get name))))

;;;###autoload
(defun emacspeak-wizards-tune-in-radio-search ()
  "Search Tune-In Radio."
  (interactive)
  (require 'emacspeak-url-template)
  (let ((name "RadioTime Search"))
    (emacspeak-url-template-open (emacspeak-url-template-get name))))

;;}}}
;;{{{ alpha-vantage: Stock Quotes

;;;alpha-vantage:
;;; API Key: https://www.alphavantage.co/support/#api-key
;;; API Documentation: https://www.alphavantage.co/documentation/

(defcustom emacspeak-wizards-alpha-vantage-api-key nil
  "API Key  used to retrieve stock data from alpha-vantage.
Visit https://www.alphavantage.co/support/#api-key to get your key."
  :type
  '(choice :tag "Key"
           (const :tag "Unspecified" nil)
           (string :tag "API Key"))
  :group 'emacspeak-wizards)

(defvar emacspeak-wizards-alpha-vantage-base
  "https://www.alphavantage.co/query?function=%s&symbol=%s&apikey=%s&datatype=csv"
  "Rest End-Point For Alpha-Vantage Stock API.")

(defun emacspeak-wizards-alpha-vantage-uri (func ticker)
  "Return URL for calling Alpha-Vantage API."
  (cl-declare (special emacspeak-wizards-alpha-vantage-base
                       emacspeak-wizards-alpha-vantage-api-key))
  (format
   emacspeak-wizards-alpha-vantage-base
   func ticker emacspeak-wizards-alpha-vantage-api-key))


(defconst ems--alpha-vantage-funcs
  '("TIME_SERIES_INTRADAY" "TIME_SERIES_DAILY_ADJUSTED"
    "TIME_SERIES_WEEKLY_ADJUSTED" "TIME_SERIES_MONTHLY_ADJUSTED")
  "Alpha-Vantage query types.")

(defcustom emacspeak-wizards-personal-portfolio "goog aapl fb amzn"
  "Set this to the stock tickers you want to check. Default is
GAFA. Tickers are separated by white-space and are automatically
sorted in lexical order with duplicates removed when saving."
  :type 'string
  :group 'emacspeak-wizards
  :initialize 'custom-initialize-reset
  :set
  #'(lambda (sym val)
      (set-default
       sym
       (mapconcat
        #'identity
        (cl-remove-duplicates
         (sort (split-string val) #'string-lessp) :test #'string=)
        "\n"))))


(defun emacspeak-wizards-alpha-vantage-quotes (ticker &optional custom)
  "Retrieve stock quote data from Alpha Vantage. Prompts for `ticker'
--- a stock symbol. Optional interactive prefix arg `custom' provides
access to the various functions provided by alpha-vantage."
  (interactive
   (list
    (upcase
     (completing-read "Stock Symbol: "
                      (split-string emacspeak-wizards-personal-portfolio)))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-personal-portfolio
                       ems--alpha-vantage-funcs))
  (let* ((completion-ignore-case t)
         (method
          (if custom
              (upcase (ido-completing-read "Choose: " ems--alpha-vantage-funcs))
            "TIME_SERIES_DAILY"))
         (url
          (emacspeak-wizards-alpha-vantage-uri
           method
           ticker)))
    (kill-new url)
    (emacspeak-table-view-csv-url url (format "%s Data For %s" method ticker))))

;;}}}
;;{{{ Stock Quotes from iextrading
;;; Moving from iextrading to iexcloud.
;;; This service is the new iextrading, but needs an API key.
;;; The service still has a free tier that should be sufficient for
;;;Emacspeak users.
;;; API Docs at https://iexcloud.io/docs/api/

(defcustom emacspeak-iex-api-key nil
  "Web API  key for IEX Finance access.
See IEX Login Console   at
https://iexcloud.io/cloud-login/
for how to get  an API key. "
  :type
  '(choice :tag "Key"
           (const :tag "Unspecified" nil)
           (string :tag "API Key"))
  :group 'emacspeak-wizards)

(defcustom emacspeak-wizards-iex-quotes-row-filter
  '(0 " ask  " 2
      " trading between   " 4 " and  " 5
      " PE is " 10
      " For a market cap of " 9)
  "Template used to audio-format  rows."
  :type '(repeat
          (choice :tag "Entry"
                  (integer :tag "Column Number:")
                  (string :tag "Text")))
  :group 'emacspeak-wizards)

(defvar emacspeak-wizards-iex-portfolio-file
  (expand-file-name "portfolio.json" emacspeak-resource-directory)
  "Local file cache of IEX API data.")

(defconst ems--iex-types
                                        ;(mapconcat #'identity '("quote" "financials" "news" "stats") ",")
  "quote"
  "Iex query types.")

(defvar emacspeak-wizards-iex-cache
  (when (file-exists-p emacspeak-wizards-iex-portfolio-file)
    (ems--json-read-file emacspeak-wizards-iex-portfolio-file))
  "Cache retrieved data to save API calls.")

(defconst emacspeak-wizards-iex-base
  "https://cloud.iexapis.com/stable"
  "Rest End-Point For iex Stock API.")

(defun emacspeak-wizards-iex-uri (action symbols)
  "Return URL for calling iex API.
Parameter `action' specifies relative URL. '"
  (cl-declare (special emacspeak-wizards-iex-base
                       ems--iex-types emacspeak-iex-api-key))
  (format
   "%s/%s?symbols=%s&token=%s&types=%s"
   emacspeak-wizards-iex-base action symbols
   emacspeak-iex-api-key
   ems--iex-types))

(defun emacspeak-wizards-iex-refresh ()
  "Retrieve stock quote data from IEX Trading.
Uses symbols set in `emacspeak-wizards-personal-portfolio '.
Caches results locally in `emacspeak-wizards-iex-portfolio-file'."
  (cl-declare (special emacspeak-wizards-iex-portfolio-file g-curl-program
               emacspeak-wizards-personal-portfolio emacspeak-wizards-iex-cache))
  (let* ((symbols
          (mapconcat
           #'identity
           (split-string emacspeak-wizards-personal-portfolio) ","))
         (url (emacspeak-wizards-iex-uri  "stock/market/batch" symbols)))
    (shell-command
     (format "%s -s -D %s/iex-headers -o %s '%s'"
             g-curl-program temporary-file-directory
             emacspeak-wizards-iex-portfolio-file url))
    (setq emacspeak-wizards-iex-cache (ems--json-read-file emacspeak-wizards-iex-portfolio-file))))

(defun emacspeak-wizards-iex-show-metadata ()
  "Account metadata."
  (interactive)
  (cl-declare (special emacspeak-wizards-iex-base))
  (message "%s"
           (g-json-from-url
            (format "%s/account/metadata?token=%s" emacspeak-wizards-iex-base emacspeak-iex-api-key))))


(defun emacspeak-wizards-iex-show-price (symbol)
  "Quick Quote: Just stock price from IEXCloud."
  (interactive
   (list
    (completing-read "Stock Symbol: " (split-string emacspeak-wizards-personal-portfolio))))
  (cl-declare (special emacspeak-wizards-iex-base
                       emacspeak-wizards-personal-portfolio))
  (let-alist
      (aref
       (g-json-from-url
        (format "%s/tops/last?symbols=%s&token=%s"
                emacspeak-wizards-iex-base symbol emacspeak-iex-api-key))
       0)
    (message "%s: %s at %s"
             symbol .price
             (format-time-string
              "%_I %M %p" (seconds-to-time (/ .time 1000))))))

(defvar ems--wizards-iex-quotes-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "F" 'emacspeak-wizards-iex-this-financials)
    (define-key map "N" 'emacspeak-wizards-iex-this-news)
    (define-key map "P" 'emacspeak-wizards-iex-this-price)
    map)
  "Local keymap used in quotes view.")


(defun emacspeak-wizards-iex-show-quote (&optional refresh)
  "Show portfolio  data from cache.
Optional interactive prefix arg forces cache refresh.

The quotes view uses emacspeak's table mode.
In addition,  the following  keys are available :

F: Show financials for current stock.
N: Show news for current stock.
P: Show live price for current stock."
  (interactive "P")
  (cl-declare (special emacspeak-wizards-iex-cache))
  (when (or refresh (null emacspeak-wizards-iex-cache))
    (emacspeak-wizards-iex-refresh))
  (let* ((buff (get-buffer-create "*Stock Quotes From IEXTrading*"))
         (inhibit-read-only t)
         (results
          (cl-loop
           for i in emacspeak-wizards-iex-cache collect
           (let-alist i .quote)))
         (count 1)
         (table (make-vector (1+ (length results)) nil)))
    (aset table 0
          ["CompanyName" "Symbol"
           "lastTrade" "Open" "Low" "High" "Close"
           "52WeekLow" "52WeekHigh" 
           "MarketCap" "PERatio"
           "Previous Close" "Change" "Change %"])
    (cl-loop
     for r in results do
     (aset table count
           (apply
            #'vector
            (let-alist r
              (list
               .companyName .symbol
               .latestPrice .open .low .high .close
               .week52Low .week52High
               .marketCap .peRatio
               .previousClose .change .changePercent))))
     (setq count (1+ count)))
    (emacspeak-table-prepare-table-buffer
     (emacspeak-table-make-table table) buff)
    (funcall-interactively #'switch-to-buffer buff)
    (setq
     emacspeak-table-speak-element 'emacspeak-table-speak-row-header-and-element
     emacspeak-table-speak-row-filter emacspeak-wizards-iex-quotes-row-filter
     header-line-format
     (format "Stock Quotes From IEXTrading"))
    (put-text-property
     (point-min) (point-max)
     'keymap ems--wizards-iex-quotes-keymap)
    (funcall-interactively #'emacspeak-table-goto 1 2)))

(defun emacspeak-wizards-iex-show-tops ()
  "Uses tops/last end-point to show brief portfolio quotes."
  (interactive)
  (cl-declare (special emacspeak-wizards-iex-base
                       emacspeak-iex-api-key))
  (let* ((buff (get-buffer-create "*Brief Stock Quotes From IEXTrading*"))
         (inhibit-read-only t)
         (i 1)
         (symbols
          (mapconcat #'identity
                     (split-string emacspeak-wizards-personal-portfolio)
                     ","))
         (url
          (format "%s/tops/last?symbols=%s&token=%s"
                  emacspeak-wizards-iex-base symbols emacspeak-iex-api-key))
         (results (g-json-from-url url))
         (table (make-vector (1+ (length results)) nil)))
    (aset table 0 ["Symbol" "Price"  "Time"])
    (cl-loop
     for r across results do
     (let-alist r
       (aset table i
             (apply #'vector
                    (list
                     .symbol .price
                     (format-time-string
                      "%_I %M %p" (seconds-to-time (/ .time 1000))))))
       (setq i (1+ i))))
    (emacspeak-table-prepare-table-buffer
     (emacspeak-table-make-table table) buff)
    (funcall-interactively #'switch-to-buffer buff)
    (setq
     emacspeak-table-speak-row-filter '(0  1 " at " 2)
     emacspeak-table-speak-element 'emacspeak-table-speak-row-filtered
     header-line-format
     (format "Brief Stock Quotes From IEXTrading"))
    (put-text-property
     (point-min) (point-max)
     'keymap ems--wizards-iex-quotes-keymap)
    (funcall-interactively #'emacspeak-table-goto 1 1)))


(defun emacspeak-wizards-iex-show-news (symbol &optional refresh)
  "Show news for specified ticker.
Checks cache, then makes API call if needed.
Optional interactive prefix arg refreshes cache."
  (interactive
   (list
    (completing-read
     "Symbol: "
     (split-string emacspeak-wizards-personal-portfolio))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-iex-cache
                       emacspeak-iex-api-key))
  (when (or refresh (null emacspeak-wizards-iex-cache))
    (emacspeak-wizards-iex-refresh))
  (let* ((inhibit-read-only t)
         (buff (get-buffer-create (format "News For %s" symbol)))
         (title (format "Stock News From IEXTrading For %S" (upcase symbol)))
         (this nil)
         (result (assq (intern (upcase symbol)) emacspeak-wizards-iex-cache)))
    (with-current-buffer buff
      (erase-buffer)
      (org-mode)
      (goto-char (point-min))
      (insert title "\n\n")
      (setq this (let-alist result .news))
      (unless this                      ; not in cache
        (setq this
              (g-json-from-url
               (format "%s/stock/%s/news?token=%s"
                       emacspeak-wizards-iex-base symbol
                       emacspeak-iex-api-key))))
      (mapc
       #'(lambda (n)
           (let-alist n
             (insert
              (format
               "  - [[%s][%s]] %s \n"
               .url .headline .source))))
       this)
      (setq buffer-read-only t)
      (setq header-line-format title))
    (funcall-interactively #'switch-to-buffer buff)
    (goto-char (point-min))))


(defun emacspeak-wizards-iex-show-financials (symbol &optional refresh)
  "Show financials for specified ticker.
Checks cache, then makes API call if needed.
Optional interactive prefix arg refreshes cache."
  (interactive
   (list
    (completing-read
     "Symbol: "
     (split-string emacspeak-wizards-personal-portfolio))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-iex-cache
                       emacspeak-wizards-iex-base
                       emacspeak-iex-api-key))
  (when (or refresh (null emacspeak-wizards-iex-cache))
    (emacspeak-wizards-iex-refresh))
  (let* ((buff (get-buffer-create (format "Financials For %s" symbol)))
         (this nil)
         (table nil)
         (headers nil)
         (result (assq (intern (upcase symbol)) emacspeak-wizards-iex-cache)))
    (cond
     (result                            ; in cache
      (setq this (let-alist result .financials.financials)))
     (t                                 ; not in cache
      (setq this
            (let-alist
                (g-json-from-url
                 (format "%s/stock/%s/financials?token=%s"
                         emacspeak-wizards-iex-base symbol
                         emacspeak-iex-api-key))
              .financials))))
    (cl-assert (arrayp this) t "Not an array.")
    (setq headers
          (apply #'vector
                 (mapcar
                  #'(lambda (h) (format "%s" (car h)))
                  (aref this 0))))
    (setq table (make-vector (1+ (length this)) nil))
    (aset table 0 headers)
    (cl-loop
     for i from 0 to (1- (length this)) do
     (aset
      table
      (+ i 1)
      (apply
       #'vector
       (mapcar #'(lambda (v) (format "%s" (cdr v)))
               (aref this i)))))
    (emacspeak-table-prepare-table-buffer
     (emacspeak-table-make-table table) buff)
    (funcall-interactively #'switch-to-buffer buff)
    (setq
     header-line-format
     (format "Financials For %s From IEXTrading" (upcase symbol))
     emacspeak-table-speak-element
     'emacspeak-table-speak-column-header-and-element)
    (funcall-interactively #'emacspeak-table-goto 1 2)))

;;; Top-Level Dispatch:
;;;###autoload
(defun emacspeak-wizards-quote (&optional refresh)
  "Top-level dispatch for looking up Stock Market information.

Key : Action
f   :  Financials
m   :  Account metadata 
n   :  News
p   :  Price
q   :  Quotes
t   :  tops/last 
"
  (interactive "P")
  (cl-case
      (read-char "f: Financials, n: News, p: Price, q: Quotes, t: tops, m:metadata")
    (?f (call-interactively #'emacspeak-wizards-iex-show-financials))
    (?p (call-interactively #'emacspeak-wizards-iex-show-price))
    (?n (call-interactively #'emacspeak-wizards-iex-show-news))
    (?m (call-interactively #'emacspeak-wizards-iex-show-metadata)) 
    (?q (funcall-interactively #'emacspeak-wizards-iex-show-quote
                               refresh))
    (?t (call-interactively #'emacspeak-wizards-iex-show-tops))
    (otherwise (error "Invalid key"))))
;;; Define emacspeak-wizards-iex-this-news and friends
(cl-loop
 for n in
 '(financials news price) do
 (eval
  `(defun
       ,(intern (format "emacspeak-wizards-iex-this-%s" n))
       ()
     ,(format "Show %s for symbol in current row" n)
     (interactive)
     (cl-declare (special emacspeak-table))
     (funcall-interactively
      (symbol-function
       ',(intern (format "emacspeak-wizards-iex-show-%s" n)))
      (aref
       (aref
        (emacspeak-table-elements emacspeak-table)
        (emacspeak-table-current-row emacspeak-table))
       1)))))

;;}}}
;;{{{ Sports API:

(defvar emacspeak-wizards--xmlstats-standings-uri
  "https://erikberg.com/%s/standings.json"
  "URI Rest end-point template for standings in a given sport.
At present, handles mlb, nba.")

(defun emacspeak-wizards-xmlstats-standings-uri (sport)
  "Return REST URI end-point,
where `sport' is either mlb or nba."
  (format emacspeak-wizards--xmlstats-standings-uri sport))

(defun emacspeak-wizards--format-mlb-standing (s)
  "Format  MLB standing."
  (let-alist s
    (format
     "** %s %s  are %s in the %s %s.
They are at  %s/%s after %s games for an average of %s.
Current streak is %s; Win/Loss at Home: %s/%s, Away: %s/%s, Conference: %s/%s.
\n"
     .first_name .last_name .ordinal_rank .conference .division
     .won .lost .games_played .win_percentage
     .streak .home_won .home_lost .away_won .away_lost
     .conference_won .conference_lost)))

(defun emacspeak-wizards-mlb-standings (&optional raw)
  "Display MLB standings as of today.
Optional interactive prefix arg shows  unprocessed results."
  (interactive "P")
  (let ((buffer (get-buffer-create "*MLB Standings*"))
        (date (format-time-string "%B %e %Y"))
        (inhibit-read-only t)
        (standings
         (g-json-from-url (emacspeak-wizards-xmlstats-standings-uri "mlb"))))
    (with-current-buffer buffer
      (erase-buffer)
      (special-mode)
      (org-mode)
      (insert (format "* Standings: %s\n\n" date))
      (cond
       (raw
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (cl-loop
          for f in s do
          (insert (format "%s:\t%s\n"
                          (car f) (cdr f))))
         (insert "\n")))
       (t
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (insert (emacspeak-wizards--format-mlb-standing s)))))
      (goto-char (point-min))
      (funcall-interactively #'pop-to-buffer buffer))))

(defun emacspeak-wizards--format-nba-standing (s)
  "Format  NBA standing."
  (let-alist s
    (format
     "%s %s  are %s in the %s %s.
They are at  %s/%s after %s games for an average of %s.
Current streak is %s; Win/Loss at Home: %s/%s, Away: %s/%s, Conference: %s/%s.
\n"
     .first_name .last_name .ordinal_rank .conference .division
     .won .lost .games_played .win_percentage
     .streak .home_won .home_lost .away_won .away_lost
     .conference_won .conference_lost)))

(defun emacspeak-wizards-nba-standings (&optional raw)
  "Display NBA standings as of today.
Optional interactive prefix arg shows  unprocessed results."
  (interactive "P")
  (let ((buffer (get-buffer-create "*NBA Standings*"))
        (date (format-time-string "%B %e %Y"))
        (inhibit-read-only t)
        (standings
         (g-json-from-url (emacspeak-wizards-xmlstats-standings-uri "nba"))))
    (with-current-buffer buffer
      (erase-buffer)
      (special-mode)
      (insert (format "Standings: %s\n\n" date))
      (cond
       (raw
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (cl-loop
          for f in s do
          (insert (format "%s:\t%s\n"
                          (car f) (cdr f))))
         (insert "\n")))
       (t
        (cl-loop
         for s across (g-json-get 'standing standings) do
         (insert (emacspeak-wizards--format-nba-standing s)))))
      (goto-char (point-min))
      (funcall-interactively #'pop-to-buffer buffer))))

;;}}}
;;{{{ Color at point:
(defun ems--color-diff (c1 c2)
  "Color difference"
  (color-cie-de2000
   (apply #'color-srgb-to-lab (color-name-to-rgb c1))
   (apply #'color-srgb-to-lab (color-name-to-rgb c2))))

;;;###autoload
(defun emacspeak-wizards-set-colors ()
  "Interactively prompt for foreground and background colors."
  (interactive)
  (let ((bg (read-color "Background: "))
        (fg (read-color "Foreground: ")))
    (set-background-color bg)
    (set-foreground-color fg)
    (emacspeak-wizards-color-diff-at-point)))

;;;###autoload
(defun emacspeak-wizards-color-diff-at-point (&optional set)
  "Meaningfully speak difference between background and foreground color at point.
With interactive prefix arg, set foreground and background color first."
  (interactive "P")
  (when set (call-interactively #'emacspeak-wizards-set-colors))
  (let* ((fg (foreground-color-at-point))
         (bg (background-color-at-point))
         (diff (ems--color-diff fg bg)))
    (message "Color distance is %.2f between %s and %s which is %s" diff
             (ems--color-name fg) (ems--color-name bg)
             (cdr (assq 'background-mode (frame-parameters))))))

(defun ems--color-hex (color)
  "Return Hex value for color."
  (apply #'color-rgb-to-hex (append (color-name-to-rgb color) '(2))))

(defun ems--color-name (color)
  "Return a meaningful color-name using name-this-color if available.
Otherwise just return  `color'."
  (interactive "P")
  (cond
   ((fboundp 'ntc-name-this-color) (ntc-name-this-color color))
   (t color)))

(defun emacspeak-wizards-frame-colors ()
  "Display frame's foreground/background color seetting."
  (interactive)
  (message "%s on %s"
           (ems--color-name (frame-parameter (selected-frame) 'foreground-color))
           (ems--color-name
            (frame-parameter (selected-frame) 'background-color))))

(defun emacspeak-wizards--set-color (color)
  "Set color as foreground or background."
  (let ((choice (read-char "f:foreground, b:background")))
    (cl-case choice
      (?b (set-background-color color))
      (?f (set-foreground-color color)))
    (emacspeak-auditory-icon 'select-object)
    (call-interactively #'emacspeak-wizards-frame-colors)))

;;;###autoload
(defun emacspeak-wizards-colors ()
  "Display list of colors and setup a callback to activate color
under point as either the foreground or background color."
  (interactive)
  (list-colors-display nil nil '#'emacspeak-wizards--set-color))

;;;###autoload
(defun emacspeak-wizards-color-at-point ()
  "Echo foreground/background color at point."
  (interactive)
  (let ((weight (faces--attribute-at-point :weight))
        (slant (faces--attribute-at-point :slant))
        (family (faces--attribute-at-point :family)))
    (message "%s %s %s %s on %s"
             (if family family "")
             (if (eq 'normal weight) "" weight)
             (if (eq 'normal slant) "" slant)
             (ems--color-name (foreground-color-at-point))
             (ems--color-name (background-color-at-point)))))

;;}}}
;;{{{ Color Wheel:
(cl-defstruct ems--color-wheel
  "Color wheel holds RGB balues and step-size."
  red green blue step)

(defun ems--color-wheel-hex (w)
  "Return color value as hex."
  (format "#%02X%02X%02X"
          (ems--color-wheel-red w)
          (ems--color-wheel-green w)
          (ems--color-wheel-blue w)))

(defun ems--color-wheel-name (wheel)
  "Name of color  the wheel is set to currently."
  (ntc-name-this-color
   (format "#%02X%02X%02X"
           (ems--color-wheel-red wheel)
           (ems--color-wheel-green wheel)
           (ems--color-wheel-blue wheel))))

(defun ems--color-wheel-shade (wheel)
  "Shade of color  the wheel is set to currently."
  (ntc-shade-this-color
   (format "#%02X%02X%02X"
           (ems--color-wheel-red wheel)
           (ems--color-wheel-green wheel)
           (ems--color-wheel-blue wheel))))

(defun ems--color-wheel-describe (w fg)
  "Describe the current state of this color wheel."
  (let ((name (ems--color-wheel-name w))
        (hexcol
         (format "#%02X%02X%02X"
                 (ems--color-wheel-red w)
                 (ems--color-wheel-green w)
                 (ems--color-wheel-blue w)))
        (hex
         (format "%02X %02X %02X"
                 (ems--color-wheel-red w)
                 (ems--color-wheel-green w)
                 (ems--color-wheel-blue w)))
        (msg nil))
    (cond
     ((string= fg "red")
      (put-text-property 0 2 'personality voice-bolden hex))
     ((string= fg "green")
      (put-text-property 3 5 'personality voice-bolden hex))
     ((string= fg "blue")
      (put-text-property 6 8 'personality voice-bolden hex)))
    (setq msg (format "%s is a %s shade: %s"
                      name (ems--color-wheel-shade w) hex))
    (setq msg
          (propertize msg 'face `(:foreground ,fg :background ,hexcol)))
    msg))

;;;### autoload
(defun emacspeak-wizards-color-wheel (start)
  "Interactively manipulate a simple color wheel and display the name
  and shade of the resulting color.  This makes for a fun color
  exploration tool with verbal descriptions of the colors from package
  name-this-color. Prompts for a color from which to start exploration.

Keyboard Commands During Interaction:
Up/Down: Increase/Decrement along current axis using specified step-size.
=: Set value on current axis to number read from minibuffer.
Left/Right: Switch color axis along which to move.
b/f: Quit  wheel after setting background/foreground color to current value.
n: Read color name from minibuffer.
c: Complement  current color.
s: Set stepsize to number read from minibuffer.
q: Quit color wheel, after copying current hex value to kill-ring."
  (interactive (list (color-name-to-rgb (read-color "Start Color: "))))
  (cl-declare (special ems--color-wheel))
  (unless (featurep 'name-this-color)
    (error "This tool requires package name-this-color."))
  (setq start (mapcar #'(lambda (c) (round (* 255 c))) start))
  (let ((continue t)
        (colors '("red" "green" "blue"))
        (color "red")
        (this 0)
        (event nil)
        (w (make-ems--color-wheel
            :red (cl-first start)
            :green (cl-second start)
            :blue (cl-third start)
            :step 8)))
    (while continue
      (setq event (read-event (ems--color-wheel-describe w color)))
      (cond
       ((eq event ?c)
        (emacspeak-auditory-icon 'button)
        (setf (ems--color-wheel-red w) (- 255 (ems--color-wheel-red w)))
        (setf (ems--color-wheel-green w) (- 255 (ems--color-wheel-green w)))
        (setf (ems--color-wheel-blue w) (- 255 (ems--color-wheel-blue w))))
       ((eq event ?q)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (message "Copied color %s %s to kill ring"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?f)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (set-foreground-color (ems--color-wheel-hex w))
        (message "Setting foreground  color  to %s %s"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?b)
        (setq continue nil)
        (emacspeak-auditory-icon 'close-object)
        (set-background-color (ems--color-wheel-hex w))
        (message "Setting background color  to %s %s"
                 (ems--color-wheel-hex w)
                 (ems--color-wheel-name w))
        (kill-new (ems--color-wheel-hex w)))
       ((eq event ?s)
        (setf (ems--color-wheel-step w) (read-number "Step size: ")))
       ((eq event 'left)
        (setq this (% (+ this 2) 3))
        (setq color (elt colors this))
        (dtk-speak (format "%s Axis" color)))
       ((eq event 'right)
        (setq this (% (+ this 1) 3))
        (setq color (elt colors this))
        (dtk-speak (format "%s Axis" color)))
       ((eq event ?n)
        (setq start
              (mapcar #'(lambda (c) (round (* 255 c)))
                      (color-name-to-rgb (read-color "Start Color: "))))
        (setf (ems--color-wheel-red w) (cl-first start))
        (setf (ems--color-wheel-green w) (cl-second start))
        (setf (ems--color-wheel-blue w) (cl-third start)))
       ((eq event ?=)
        (cond
         ((string= color "red")
          (setf (ems--color-wheel-red w) (read-number "Red:"))
          (setf (ems--color-wheel-red w)
                (min 255 (ems--color-wheel-red w))))
         ((string= color "green")
          (setf (ems--color-wheel-green w) (read-number "Green:"))
          (setf (ems--color-wheel-green w)
                (min 255 (ems--color-wheel-green w))))
         ((string= color "blue")
          (setf (ems--color-wheel-blue w) (read-number "Blue:"))
          (setf (ems--color-wheel-blue w)
                (min 255 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       ((eq event 'up)
        (cond
         ((string= color "red")
          (cl-incf (ems--color-wheel-red w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-red w)
                (min 255 (ems--color-wheel-red w))))
         ((string= color "green")
          (cl-incf (ems--color-wheel-green w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-green w)
                (min 255 (ems--color-wheel-green w))))
         ((string= color "blue")
          (cl-incf (ems--color-wheel-blue w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-blue w)
                (min 255 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       ((eq event 'down)
        (cond
         ((string= color "red")
          (cl-decf (ems--color-wheel-red w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-red w)
                (max 0 (ems--color-wheel-red w))))
         ((string= color "green")
          (cl-decf (ems--color-wheel-green w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-green w)
                (max 0 (ems--color-wheel-green w))))
         ((string= color "blue")
          (cl-decf (ems--color-wheel-blue w) (ems--color-wheel-step w))
          (setf (ems--color-wheel-blue w)
                (max 0 (ems--color-wheel-blue w))))
         (t (error "Unknown color %s" color))))
       (t
        (message
         "Left/Right Switches primary, Up/Down increases/decrements."))))))

;;}}}
;;{{{ Swap Foreground And Background:

;;;###autoload
(defun emacspeak-wizards-swap-fg-and-bg ()
  "Swap foreground and background."
  (interactive)
  (let ((fg (foreground-color-at-point))
        (bg (background-color-at-point)))
    (set-foreground-color bg)
    (set-background-color fg)
    (call-interactively #'emacspeak-wizards-color-diff-at-point)))

;;}}}
;;{{{ Utility: Read from a pipe helper:

;;; For use from etc/emacs-pipe.pl
;;; Above can be used as a printer command in XTerm

(defun emacspeak-wizards-pipe ()
  "convenience function"
  (pop-to-buffer (get-buffer-create " *piped*"))
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-mode-line))

;;}}}
;;{{{ Smart Scratch:


(defun emacspeak-wizards-scratch ()
  "Switch to *scratch* buffer, creating it if necessary."
  (interactive)
  (let ((buffer (get-buffer-create "*scratch*")))
    (with-current-buffer buffer (lisp-interaction-mode))
    (funcall-interactively #'pop-to-buffer buffer)))

;;}}}
;;{{{ Customize Saved Settings  By Pattern:

;;; Emacs' built-in customize-saved can be slow if the saved
;;; customizations are many. This function allows one to clean-up
;;; saved settings in smaller groups by specifying a pattern to match.

(defun emacspeak-wizards-customize-saved (pattern)
  "Customize saved options matching `pattern'.  This command enables
updating custom settings for a specific package or group of packages."
  (interactive "sFilter Pattrern: ")
  (let ((found nil))
    (mapatoms #'(lambda (symbol)
                  (and (string-match pattern (symbol-name symbol))
                       (or (get symbol 'saved-value)
                           (get symbol 'saved-variable-comment))
                       (boundp symbol)
                       (push (list symbol 'custom-variable) found))))
    (when (not found) (user-error "No saved user options matching %s"
                                  pattern))
    (ems-with-messages-silenced
        (emacspeak-auditory-icon 'progress)
      (custom-buffer-create
       (custom-sort-items found t nil)
       (format "*Customize %d Saved options Matching %s*" (length
                                                           found) pattern)))
    (emacspeak-auditory-icon 'task-done)
    (emacspeak-speak-mode-line)))

;;}}}
;;{{{ NOAA Weather API:

;;; NOAA: format time
;;; NOAA data has a ":" in tz

(defun ems--noaa-time (fmt iso)
  "Utility function to correctly format ISO date-time strings from NOAA."
;;; first strip offending ":" in tz
  (when (and (= (length iso) 25) (char-equal ?: (aref iso 22)))
    (setq iso (concat (substring iso 0 22) "00")))
  (format-time-string fmt (date-to-time iso)))

(defun ems--noaa-url (&optional geo)
  "Return NOAA Weather API REST end-point for specified lat/long.
Location is a Lat/Lng pair retrieved from Google Maps API."
  (cl-declare (special gmaps-my-address))
  (cl-assert (or geo gmaps-my-address) nil "Location not specified.")
  (unless geo (setq geo (gmaps-address-geocode gmaps-my-address)))
  (format
   "https://api.weather.gov/points/%.4f,%.4f/forecast"
   (g-json-get 'lat geo) (g-json-get 'lng geo)))

(defun ems--noaa-get-data (ask)
  "Internal function that gets NOAA data and returns a results buffer."
  (cl-declare (special gmaps-my-address))
  (let* ((buffer (get-buffer-create "*NOAA Weather*"))
         (inhibit-read-only t)
         (date nil)
         (fmt "%A  %H:%M %h %d")
         (start (point-min))
         (address
          (if (and ask (= 16 (car ask)))
              (read-from-minibuffer "Address:")
            gmaps-my-address))
         (geo (if (and ask (= 16 (car ask)))
                  (gmaps-address-geocode address)
                (gmaps-address-geocode gmaps-my-address))))
    (with-current-buffer buffer
      (erase-buffer)
      (org-mode)
      (setq header-line-format (format "NOAA Weather For %s" address))
;;; produce Daily forecast
      (let-alist (g-json-from-url (ems--noaa-url geo))
        (insert
         (format "* Forecast At %s For %s\n\n"
                 (ems--noaa-time fmt .properties.updated)
                 address))
        (cl-loop
         for p across .properties.periods do
         (let-alist p
           (insert
            (format
             "** Forecast For %s: %s\n\n%s\n\n"
             .name .shortForecast .detailedForecast)))
         (fill-region start (point)))
        )
      (let-alist ;;; Now produce hourly forecast
          (g-json-from-url (concat (ems--noaa-url geo) "/hourly"))
        (insert
         (format "\n* Hourly Forecast:Updated At %s \n"
                 (ems--noaa-time fmt .properties.updated)))
        (cl-loop
         for p across .properties.periods do
         (let-alist p
           (unless (and date (string= date (ems--noaa-time "%x" .startTime)))
             (insert (format "** %s\n" (ems--noaa-time "%A %X" .startTime)))
             (setq date (ems--noaa-time "%x" .startTime)))
           (insert
            (format
             "  - %s %s %s:  Wind Speed: %s Wind Direction: %s\n"
             (ems--noaa-time "%R" .startTime)
             .shortForecast
             .temperature .windSpeed .windDirection)))))
      (setq buffer-read-only t)
      (goto-char (point-min)))
    buffer))

;;;###autoload
(defun emacspeak-wizards-noaa-weather (&optional ask)
  "Display weather information using NOAA Weather API.
Data is retrieved only once, subsequent calls switch to previously
displayed results. Kill that buffer or use an interactive prefix
arg (C-u) to get new data.  Optional second interactive prefix
arg (C-u C-u) asks for location address; Default is to display
weather for `gmaps-my-address'.  "
  (interactive "P")
  (let ((buffer
         (cond
          (ask (ems--noaa-get-data ask))
          ((get-buffer "*NOAA Weather*") (get-buffer "*NOAA Weather*"))
          (t (ems--noaa-get-data ask)))))
    (switch-to-buffer buffer)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-buffer)))

;;}}}
;;{{{ generate declare-function statements:

(declare-function help--symbol-completion-table "help-fns" (string pred action))

(defun emacspeak-wizards-gen-fn-decl (f &optional ext)
  "Generate declare-function call for function `f'.
Optional interactive prefix arg ext says this comes from an
external package."
  (interactive
   (list
    (read
     (completing-read
      "Function:"
      #'help--symbol-completion-table
      #'functionp))))
  (cl-assert (functionp f) t "Not a valid function")
  (let ((file (symbol-file f 'defun))
        (arglist (help-function-arglist f 'preserve)))
    (cl-assert file t "Function definition not found")
    (setq file (file-name-base file))
    (insert
     (format
      "(declare-function %s \"%s\" %s)\n"
      f
      (if ext (format "ext:%s" file) file)
      arglist))))

;;}}}
;;{{{ Google Newspaper:
(declare-function eww-display-dom-by-element "emacspeak-eww" (tag))

;;;###autoload
(defun emacspeak-wizards-google-news ()
  "Clean up news.google.com for  skimming the news."
  (interactive)
  (cl-declare (special emacspeak-we-xsl-junk emacspeak-we-xsl-filter))
  (add-hook
   'emacspeak-eww-post-process-hook
   #'(lambda nil (eww-display-dom-by-element 'h3)))
  (message "Press l to expand all sections.")
  (emacspeak-we-xslt-pipeline-filter
   `((,emacspeak-we-xsl-filter "//main") ;specs
     (,emacspeak-we-xsl-junk "//menu|//*[contains(@role,\"button\")]"))
   "https://news.google.com"
   'speak))

;;;###autoload
(defun emacspeak-wizards-google-headlines ()
  "Display just the headlines from Google News for fast loading."
  (interactive)
  (emacspeak-we-xslt-filter "//h3" "https://news.google.com" 'speak))

;;}}}
;;{{{ Use Threads To Call Command Asynchronously:
;;;Experimental: Handle with care.

;;;###autoload
(defun emacspeak-wizards-execute-asynchronously (key)
  "Read key-sequence, then execute its command on a new thread."
  (interactive (list (read-key-sequence "Key Sequence: ")))
  (let ((l (local-key-binding key))
        (g (global-key-binding key))
        (k
         (when-let (map (get-text-property (point) 'keymap))
                   (lookup-key map key))))
    (cl-flet
        ((do-it (command)
                (make-thread command)
                (message "Running %s on a new thread." command)))
      (cond
       ((commandp k) (do-it k))
       ((commandp l) (do-it l))
       ((commandp g) (do-it g))
       (t (error "%s is not bound to a command." key))))))

;;}}}
;;{{{Midi Playback Using MuseScore ==mscore:


(defvar emacspeak-wizards-media-pipe
  (expand-file-name "pipe.flac" emacspeak-resource-directory)
  "Named socket for piped media streams.")

;;;###autoload
(defun emacspeak-wizards-midi-using-m-score (midi-file)
  "Play midi file using mscore from musescore package."
  (interactive "fMidi File:")
  (cl-declare (special emacspeak-wizards-media-pipe))
  (cl-assert (executable-find "mscore") t "Install mscore first")
  (or (file-exists-p emacspeak-wizards-media-pipe)
      (shell-command (format "mknod %s p"
                             emacspeak-wizards-media-pipe)))
  (cl-assert (file-exists-p emacspeak-wizards-media-pipe) t
             "Error creating named socket")
  (emacspeak-m-player emacspeak-wizards-media-pipe)
  (message "converting %s to audio" midi-file)
  (shell-command
   (format "%s -o %s %s &"
           (executable-find "mscore")
           emacspeak-wizards-media-pipe midi-file)))

;;}}}
;;{{{Free GeoIP:

(defun emacspeak-wizards-free-geo-ip (&optional reverse-geocode)
  "Return list consisting of city and region_name.
Optional interactive prefix arg reverse-geocodes using Google Maps."
  (interactive "P")
  (let-alist
      (g-json-from-url "https://freegeoip.app/json")
    (if reverse-geocode
        (dtk-speak
         (gmaps-reverse-geocode
          `((lat . ,.latitude) (lng . ,.longitude ))))
      (dtk-speak-list (list  .city .region_name)))))

;;}}}
;;{{{ytel via invideous:
(declare-function ytel-get-current-video "ytel" nil)
(declare-function ytel-video-id "ytel" (cl-x))


(defvar emacspeak-wizards-yt-url-pattern
  "https://www.youtube.com/watch?v=%s"
  "Youtube URL pattern.")

;;;###autoload
(defun emacspeak-wizards-ytel-play-at-point (id &optional best)
  "Play video. Argument `id' is the video-id.
Play current video in ytel when called interactively.
Optional interactive prefix arg `best' picks best audio format."
  (interactive
   (list
    (ytel-video-id (ytel-get-current-video))
    current-prefix-arg))
  (cl-declare (special emacspeak-wizards-yt-url-pattern))
  (or (require 'ytel 'no-error)
      (error "Install package ytel from melpa."))
  (funcall-interactively
   #'emacspeak-m-player-youtube-player
   (format emacspeak-wizards-yt-url-pattern id)
   best))

(defun emacspeak-wizards-ytel-download (id )
  "Download video at point."
  (interactive
   (list (ytel-video-id (ytel-get-current-video))))
  (cl-declare (special emacspeak-m-player-youtube-dl
                       emacspeak-wizards-yt-url-pattern))
  (or (require 'ytel 'no-error)
      (error "Install package ytel from melpa."))
  (let ((default-directory (expand-file-name "~/Downloads")))
    (shell-command
     (format "%s '%s' & "
             emacspeak-m-player-youtube-dl
             (format emacspeak-wizards-yt-url-pattern id)))))

(when
    (and (locate-library "ytel")
         (boundp 'ytel-mode-map)
         (keymapp ytel-mode-map))
  (cl-declaim (special ytel-mode-map))
  (define-key  ytel-mode-map (kbd "d") #'emacspeak-wizards-ytel-download)
  (define-key  ytel-mode-map (kbd "RET") #'emacspeak-wizards-ytel-play-at-point)
  (define-key  ytel-mode-map "." #'emacspeak-wizards-ytel-play-at-point))


(defadvice ytel (after emacspeak pre act comp)
  "Provide auditory feedback."
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'opten-object)
    (emacspeak-speak-line)))

;;}}}
;;{{{  Submit bugs

(defconst emacspeak-bug-address
  "emacspeak@cs.vassar.edu"
  "Address for bug reports and questions.")

(defun emacspeak-submit-bug ()
  "Function to submit a bug to the programs maintainer."
  (interactive)
  (require 'reporter)
  (when
      (yes-or-no-p "Are you sure you want to submit a bug report? ")
    (let (
          (vars '(
                  emacs-version
                  system-type
                  emacspeak-version  dtk-program)))
      (mapc
       #'(lambda (x)
           (if (not (and (boundp x) (symbol-value x)))
               (setq vars (delq x vars))))
       vars)
      (reporter-submit-bug-report
       emacspeak-bug-address
       (concat "Emacspeak Version: " emacspeak-version)
       vars nil nil
       "Description of Problem:"))))

;;}}}
(provide 'emacspeak-wizards)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-warnings: (not noruntime )
;;; end:

;;}}}
