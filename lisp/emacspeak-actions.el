;;; emacspeak-actions.el --- Emacspeak actions -- callbacks that can be associated with portions of a buffer  -*- lexical-binding: t; -*-
;;; $Id$
;;; $Author: tv.raman.tv $
;;; Define emacspeak actions for various modes
;;; Keywords:emacspeak, audio interface to emacs actions
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;;; A speech interface to Emacs |
;;; $Date: 2007-08-25 18:28:19 -0700 (Sat, 25 Aug 2007) $ |
;;;  $Revision: 4532 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:
;;;Copyright (C) 1995 -- 2021, T. V. Raman 
;;; Copyright (c) 1995 by T. V. Raman
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
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
;;; the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,MA 02110-1301, USA.

;;}}}

;;{{{  Introduction:
;;; Commentary:

;;; Define mode-specific  actions.
;;; Actions are defined by adding them to hook
;;; emacspeak-<mode-name>-actions-hook

;;}}}
;;{{{  required modules 

;;; Code:
(require 'cl-lib)
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-sounds)
(require 'emacspeak-speak)
;;}}}
;;{{{  Define actions for emacs lisp mode

(defun emacspeak-activate-match-blinker ()
  "Setup action on right parens.
The defined   emacspeak action   causes
emacspeak to show the matching paren when the cursor moves across a right paren."
  (save-current-buffer
    (goto-char (point-min))
    (with-silent-modifications
      (while (search-forward ")" nil t)
        (put-text-property  (point) (1+ (point))
                            'emacspeak-action
                            'emacspeak-blink-matching-open)))))
(add-hook 'emacspeak-emacs-lisp-mode-actions-hook
          'emacspeak-activate-match-blinker)
;;}}}
;;{{{  Define actions for c and c++ modes

(defun emacspeak-c-speak-semantics-when-on-closing-brace ()
  "Setup action on right braces.
The defined  action    causes
emacspeak to speak the semantics of the line
 when the cursor moves across a right brace."
  (save-current-buffer
    (goto-char (point-min))
    (with-silent-modifications
      (while (search-forward "}" nil t)
        (put-text-property  (point) (1+ (point))
                            'emacspeak-action
                            'emacspeak-c-speak-semantics)))))
(add-hook 'emacspeak-c-mode-actions-hook
          'emacspeak-c-speak-semantics-when-on-closing-brace)

;;}}}
(provide  'emacspeak-actions)
;;{{{  emacs local variables

;;; local variables:
;;; folded-file: t
;;; end:

;;}}}
