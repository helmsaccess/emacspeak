;;; emacspeak-tetris.el --- Speech enable game of Tetris  -*- lexical-binding: t; -*-
;;; $Id$
;;; $Author: tv.raman.tv $ 
;;; Description: Auditory interface to tetris
;;; Keywords: Emacspeak, Speak, Spoken Output, tetris
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

;;; Copyright (c) 1995 -- 2021, T. V. Raman
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
;;; the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,MA 02110-1301, USA..

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{ Introduction:
;;; Commentary:
;;; Speech-enables tetris.
;;; Code:

;;}}}
;;{{{  Required modules

(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'tetris "tetris" 'no-error)
;;}}}
;;{{{  Introduction 

;;; Auditory interface to tetris

;;}}}
;;{{{  Setup speech display table 

(defvar emacspeak-tetris-pronunciations-defined nil
  "Indicate if tetris pronunciations are defined")

(defun emacspeak-tetris-define-pronunciations ()
  "Define speech display for tetris"
  (cl-declare (special emacspeak-tetris-pronunciations-defined
                       emacspeak-pronounce-pronunciation-table emacspeak-pronounce-dictionaries-loaded))
  (require 'emacspeak-pronounce)
  (unless emacspeak-tetris-pronunciations-defined
    (setq emacspeak-tetris-pronunciations-defined t)
    ;;; add tiles as repeating patterns 
     (cl-pushnew (format "%c" 0) dtk-cleanup-repeats )
    (mapc
     #'(lambda (entry)
         (emacspeak-pronounce-add-dictionary-entry 'tetris-mode
                                                   (car entry) (cdr entry)))
     '(("" . " 1 ")
       ("" . " 6 ")
       ("" . " 7 ")
       ("" . " 5 ")
       ("" . " 4 ")
       ("" . " 3 ")
       ("" . " 2 ")
       (" " . "-")
       ("" . "")                      ;border char
       ("." . ""))))
  (when (or (not (boundp 'emacspeak-pronounce-pronunciation-table))
            (not emacspeak-pronounce-pronunciation-table))
    (emacspeak-pronounce-toggle-use-of-dictionaries)))

;;}}}
;;{{{  tile shapes

(defvar emacspeak-tetris-shape-name-table (make-vector 8 "")
  "Names of the tiles based on their shape")

(aset emacspeak-tetris-shape-name-table 1 " block ")
(aset emacspeak-tetris-shape-name-table 2 " right elbow ")
(aset emacspeak-tetris-shape-name-table 3 " left elbow")
(aset emacspeak-tetris-shape-name-table 4 " z ")
(aset emacspeak-tetris-shape-name-table 5 " s ")
(aset emacspeak-tetris-shape-name-table 6 " inverted t ")
(aset emacspeak-tetris-shape-name-table 7 " line ")
(defun emacspeak-tetris-blank-row ()
  (cl-declare (special tetris-width))
  (make-string tetris-width  0))

(defun emacspeak-tetris-shape-name (tile)
  (cl-declare (special emacspeak-tetris-shape-name-table))
  (aref emacspeak-tetris-shape-name-table tile))

;;}}}
;;{{{  helpers
;;;we need this because in the new version a line is not a row (on the
;;;bottom)

(defun emacspeak-tetris-get-current-row ()
  (cl-declare (special tetris-border))
  (save-excursion
    (beginning-of-line)
    (let ((start nil))
      (while (not (= (following-char) tetris-border)) (forward-char 1))
      (setq start (point))
      (forward-char 1)
      (while (not (= (following-char) tetris-border)) (forward-char 1))
      (buffer-substring start (point)))))

(defun emacspeak-tetris-speak-row ()
  "Speak current tetris row"
  (interactive)
  (dtk-speak (emacspeak-tetris-get-current-row)))

(defun emacspeak-tetris-speak-row-number ()
  "Speak where on the tetris board we are"
  (interactive)
  (what-line))
(defun emacspeak-tetris-speak-x-coordinate ()
  "Speak current position"
  (interactive)
  (cl-declare  (special tetris-pos-x
                        tetris-shape))
  (message "%s at %s"
           (emacspeak-tetris-shape-name (1+ tetris-shape))
           tetris-pos-x))

(defun emacspeak-tetris-speak-coordinates ()
  "Speak current position"
  (interactive)
  (cl-declare  (special tetris-pos-x tetris-pos-y
                        tetris-shape))
  (message "%s at %s %s"
           (emacspeak-tetris-shape-name (1+ tetris-shape))
           tetris-pos-x tetris-pos-y))

(defun emacspeak-tetris-speak-current-shape ()
  "Speak current shape"
  (interactive)
  (cl-declare (special tetris-shape tetris-rot
                       tetris-next-shape
                       tetris-n-rows emacspeak-tetris-filled-a-row))
  (dtk-speak
   (format
    (format "%s %s at rotation  %s next is %s"
            (if emacspeak-tetris-filled-a-row 
                tetris-n-rows
              " ")
            (emacspeak-tetris-shape-name (1+ tetris-shape))
            tetris-rot
            (emacspeak-tetris-shape-name (1+ tetris-next-shape)))))
  (if emacspeak-tetris-filled-a-row
      (setq  emacspeak-tetris-filled-a-row nil)))

(defun emacspeak-tetris-speak-next-shape ()
  "Speak next shape"
  (interactive)
  (cl-declare (special tetris-next-shape))
  (dtk-speak
   (format "%s "
           (emacspeak-tetris-shape-name (1+ tetris-next-shape)))))

(defun emacspeak-tetris-speak-current-shape-and-coordinates ()
  "Speak shape orientation and coordinates"
  (interactive)
  (cl-declare (special  tetris-pos-x tetris-pos-y
                        tetris-shape tetris-rot))
  (message "%s at %s %s  at rotation %s"
           (emacspeak-tetris-shape-name (1+ tetris-shape))
           tetris-pos-x
           tetris-pos-y
           tetris-rot))

(defun emacspeak-tetris-speak-score()
  "Speak the score"
  (interactive)
  (cl-declare (special tetris-n-shapes tetris-n-rows
                       tetris-score
                       tetris-width))
  (dtk-speak
   (format "%s complete rows after %s tiles to score %s  for an average of %s"
           tetris-n-rows
           (1- tetris-n-shapes)
           tetris-score
           (if (> tetris-n-shapes 1)
               (/ (* 25 tetris-width  tetris-n-rows)
                  (1- tetris-n-shapes))
             ""))))

;;}}}
;;{{{  Advice

(defvar emacspeak-tetris-tick-period 15
"Set this to a convenient value so you get time to look at what is
going on. Reduce it as you get better.")

(defun emacspeak-tetris-tick-period ()
  (cl-declare (special emacspeak-tetris-tick-period))
  emacspeak-tetris-tick-period)

(cl--defalias 'tetris-get-tick-period 'emacspeak-tetris-tick-period)

(defvar emacspeak-tetris-width tetris-width
"Set this to different values for fun")

(defadvice tetris (around emacspeak pre act comp)
  "Tetris is speech-enabled by Emacspeak.
Here are some notes to get speech users started at playing this game.

Introduction:

The game involves forming rows by arranging interlocking tiles of different shapes.
When complete these rows disappear from the board.

The tiles are the seven possible shapes that can be formed by arranging four square tiles in a plane.
Emacspeak uses mnemonic names for these shapes based on their visual appearance.

Here is a description of the seven shapes.
Shape   Description
----    ------------------------------------------------------------

11     Block
11     Tiles are arranged as a 2X2 square.

222     Right Elbow
--2     A 2X3 matrix with the first two cells empty in the bottom row.

333     Left Elbow
3--     A 2X3 matrix with the last two cells empty in the bottom row.

44-     The letter Z
-44     A 2X3 matrix with empty top-right and bottom-left cells.

-55     The Letter S
55-     A 2X3 matrix with empty top-left and bottom-right cells.

-6-     Inverted T
666     a 2X3 matrix with the first and third cells in the top row empty.

7777    Edge
        Tiles arranged in a row to make a 1X4 matrix.
----    ------------------------------------------------------------

These shapes are displayed in different colors when playing the game on a graphic display.
Emacspeak uses the seven digits to indicate the tiles
and a - to indicate an empty square.

Emacspeak slows the tetris clock down so you get time to listen to the
tiles as they drop.  When running without Emacspeak, you get about
three tiles dropping per second.  With Emacspeak running, the tiles
drop as quickly as you can move them.

At each stage, Emacspeak announces the current and next tile.
You hear messages of the form:

left Elbow at rotation 0 next is Inverted T

Tiles can be translated, rotated and dropped down to the
bottom of the stack (or as far as they can drop).  The
default width of the board is 10.

In addition to the default keybindings provided by Tetris,
Emacspeak binds the following:

Key     Action
----    -------------------------

h       Translate tile left
l       Translate tile right
j       Rotate tile counter-clockwise
k       Rotate tile clockwise.

   With a visual interface, relative translations as
provided by Tetris are adequate since the user can visually
line up the current tile with the available openings at the
bottom.  In the case of a speech interface, having absolute
positioning commands, e.g. move the tile to the left edge,
are almost indispensable.

Emacspeak therefore implements and binds the following additional commands:

Key     Action
----    -----------------------------------
a       Move tile to left edge.
e       Move tile to right edge.
1..8    Move tile to absolute position 1..8

As each tile is dropped, you hear an auditory icon.
When a row is completed you hear a different icon.

Examining the state of the game:

You can examine the state of the board by cursoring around
with C-n and C-p --note that Tetris takes over the arrow
keys for translating and rotating the tiles.

In addition, Emacspeak provides the following convenience keys:

Key     Action
----    ------------------------------

b       Move to and speak bottom row
t       Move to and speak top row.
c       Speak current row.
m       Speak current row.
r       Speak row number of current row.
.       Speak current tile.
,       Speak next tile.
RET     Speak score.

Note: Playing tetris is a highly visual activity and the
purpose of speech-enabling it in Emacspeak is to understand
what actions are needed in an auditory interface to
compensate for the difference between aural and visual
interaction.  Despite the clock being slowed down, playing
Tetris with speech feedback alone requires a lot of
concentration and the game is a good mental challenge. "
  (cl-declare (special tetris-tick-period
                       emacspeak-tetris-blank-row))
  (when (ems-interactive-p)
    (setq tetris-tick-period emacspeak-tetris-tick-period)
    (setq tetris-width emacspeak-tetris-width)
    (setq emacspeak-tetris-blank-row (emacspeak-tetris-blank-row))
    ad-do-it
    (dtk-set-punctuations 'all)
    (emacspeak-tetris-define-pronunciations)
    (emacspeak-tetris-define-keys)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-tetris-speak-current-shape)
    (goto-char (point-min))
    (forward-line tetris-height)))

(defadvice tetris-start-game (after emacspeak pre act comp)
  "speak"
  (cl-declare (special emacspeak-tetris-blank-row))
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'open-object)
    (setq tetris-width emacspeak-tetris-width)
    (setq emacspeak-tetris-blank-row (emacspeak-tetris-blank-row))
    (goto-char (point-max))
    (beginning-of-line)))

(defadvice tetris-end-game (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'close-object)
    (message "Ending current game")))

(defadvice tetris-draw-next-shape (after emacspeak pre act comp)
  "Speak"
  (emacspeak-tetris-speak-current-shape))

(defadvice tetris-rotate-next (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-tetris-speak-current-shape)))

(defadvice tetris-rotate-prev (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-tetris-speak-current-shape)))

(defadvice tetris-move-left-edge (after emacspeak pre act comp)
  "Speak coordinates"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-tetris-speak-column)))

(defadvice tetris-move-right-edge (after emacspeak pre act comp)
  "Speak coordinates"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-tetris-speak-column)))

(defadvice tetris-move-to-x-pos (after emacspeak pre act comp)
  "Speak coordinates"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-tetris-speak-column)))

(defadvice tetris-move-left (after emacspeak pre act comp)
  "Speak coordinates"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-tetris-speak-column)))

(defadvice tetris-move-right (after emacspeak pre act comp)
  "Speak coordinates"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-tetris-speak-column)))

(defadvice tetris-move-bottom (after emacspeak pre act comp)
  "speak as the tile falls"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'close-object)))
(defvar emacspeak-tetris-filled-a-row nil
  "Temporary flag indicating if we just filled a row.")

(defadvice tetris-full-row (after emacspeak pre act comp)
  "Signal full rows"
  (when ad-return-value
    (setq emacspeak-tetris-filled-a-row t)
    (emacspeak-auditory-icon 'item)))

(defadvice tetris-draw-score (around emacspeak pre act comp)
  "dont draw the score"
  (when nil ad-do-it) ; to silence byte-compiler 
  )
;;}}}
;;{{{  speak line 

;;}}}
;;{{{  setup keys

(defun emacspeak-tetris-define-keys ()
  "Setup emacspeak tetris key bindings "
  (cl-declare (special tetris-mode-map))
  (define-key tetris-mode-map "v" 'emacspeak-tetris-speak-column)
  (define-key tetris-mode-map "n" 'emacspeak-self-insert-command)
  (define-key tetris-mode-map "N" 'tetris-start-game)
  (define-key  tetris-mode-map "c" 'emacspeak-tetris-speak-row)
  (cl-loop for i from 0 to 9
           do
           (define-key tetris-mode-map
             (format "%s" i)
             'tetris-move-to-x-pos))
  (define-key tetris-mode-map "a" 'tetris-move-left-edge)
  (define-key tetris-mode-map "e" 'tetris-move-right-edge)
  (define-key tetris-mode-map "l" 'tetris-move-right)
  (define-key tetris-mode-map "h" 'tetris-move-left)
  (define-key tetris-mode-map "j" 'tetris-rotate-next)
  (define-key tetris-mode-map "k" 'tetris-rotate-prev)
  (define-key tetris-mode-map "\C-m" 'emacspeak-tetris-speak-score)
  (define-key tetris-mode-map "."
    'emacspeak-tetris-speak-current-shape-and-coordinates)
  (define-key tetris-mode-map "," 'emacspeak-tetris-speak-next-shape)
  (define-key tetris-mode-map "m" 'emacspeak-tetris-speak-row)
  (define-key tetris-mode-map "b" 'emacspeak-tetris-goto-bottom-row)
  (define-key tetris-mode-map "t" 'emacspeak-tetris-goto-top-row)
  (define-key tetris-mode-map "r" 'emacspeak-tetris-speak-row-number)
  )

;;}}}
;;{{{ Additional navigation commands

(defun emacspeak-tetris-goto-bottom-row ()
  "Move to and speak bottom row"
  (interactive)
  (cl-declare (special tetris-height))
  (ems-with-messages-silenced
      (goto-char (point-max))
    (forward-line -2))
  (emacspeak-tetris-speak-row))

(defvar emacspeak-tetris-blank-row
  (emacspeak-tetris-blank-row)
  "String matching a blank row of the board")

(defun emacspeak-tetris-goto-top-row ()
  "Move to and speak the top row"
  (interactive)
  (cl-declare (special tetris-height
                       emacspeak-tetris-blank-row))
  (goto-char (point-max))
  (search-backward emacspeak-tetris-blank-row  nil t)
  (forward-line 1)
  (emacspeak-tetris-speak-row))

(defun tetris-move-left-edge ()
  "Moves the shape to the left edge  of the playing area"
  (interactive)
  (cl-declare (special tetris-pos-x tetris-width))
  (let ((hit nil))
    (tetris-erase-shape)
    (while(and (> tetris-pos-x 0)
               (not hit))
      (setq tetris-pos-x (1- tetris-pos-x))
      (setq hit (tetris-test-shape)))
    (tetris-draw-shape)))

(defun tetris-move-right-edge ()
  "Moves the shape to the right edge  of the playing area"
  (interactive)
  (cl-declare (special tetris-pos-x tetris-width))
  (let ((hit nil)
        (max(- tetris-width (tetris-shape-width))))
    (tetris-erase-shape)
    (while(and (< tetris-pos-x max)
               (not hit))
      (setq tetris-pos-x (1+ tetris-pos-x))
      (setq hit (tetris-test-shape)))
    (tetris-draw-shape)))

(defun tetris-move-to-x-pos ()
  "Moves the shape to a specified x position if possible"
  (interactive)
  (cl-declare (special tetris-pos-x tetris-width))
  (let ((hit nil)
        (x
         (condition-case nil
             (read (format "%c" last-input-event))
           (error nil)))
        (max(- tetris-width (tetris-shape-width)))
        (diff nil))
    (setq diff (- x tetris-pos-x))
    (tetris-erase-shape)
    (cond
     ((cl-plusp diff)
      (while(and (< tetris-pos-x max)
                 (> diff 0)
                 (not hit))
        (setq tetris-pos-x (1+ tetris-pos-x))
        (setq hit (tetris-test-shape))
        (cl-decf diff)))
     ((cl-minusp diff)
      (while(and (> tetris-pos-x 0)
                 (cl-minusp diff)
                 (not hit))
        (setq tetris-pos-x (1- tetris-pos-x))
        (setq hit (tetris-test-shape))
        (cl-incf diff))))
    (tetris-draw-shape)))

;;}}}
;;{{{ column browsing

(defun emacspeak-tetris-get-column-contents (x)
  "Return column contents as a string"
  (cl-declare (special tetris-height tetris-top-left-y
                       tetris-top-left-x))
  (let ((result nil))
    (setq x (+ tetris-top-left-x x))
    (setq result
          (cl-loop for y from tetris-top-left-y
                   to (+ tetris-height tetris-top-left-y)
                   collect (gamegrid-get-cell x y)))
    (mapconcat 'char-to-string result "")))

(defun emacspeak-tetris-speak-column (&optional x)
  "Speak  column --default is to speak current column"
  (interactive "p")
  (cl-declare (special tetris-pos-x))
  (or  x (setq x tetris-pos-x))
  (when  (sit-for 0.5 'no-disp)
    (dtk-speak (emacspeak-tetris-get-column-contents x))))

;;}}}
;;{{{ Mode hook:

(add-hook
 'tetris-mode-hook
 #'(lambda ()
     (voice-lock-mode -1)))

;;}}}
(provide 'emacspeak-tetris)
;;{{{ end of file 

;;; local variables:
;;; folded-file: t
;;; end: 

;;}}}
