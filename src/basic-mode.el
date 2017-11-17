;;; basic-mode.el --- major mode for editing BASIC code

;; Copyright (C) 2017 Johan Dykstrom

;; Author: Johan Dykstrom
;; Created: Sep 2017
;; Version: 0.3.0-SNAPSHOT
;; Keywords: basic, languages
;; URL: https://github.com/dykstrom/basic-mode
;; Package-Requires: ((seq "2.20") (emacs "24.3"))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a major mode for editing BASIC code,
;; including syntax highlighting and indentation.
;;
;; You can format the region, or the entire buffer, by typing C-c C-f.

;; Installation:

;; The easiest way to install basic-mode is from MELPA, please see
;; https://melpa.org.
;;
;; To install manually, place basic-mode.el in your load-path, and add
;; the following lines of code to your init file:
;;
;; (autoload 'basic-mode "basic-mode" "Major mode for editing BASIC code." t)
;; (add-to-list 'auto-mode-alist '("\\.bas\\'" . basic-mode))

;; Configuration:

;; You can customize the indentation of code blocks, see variable
;; `basic-indent-offset'. The default value is 4.
;;
;; You can also customize the number of columns to use for line
;; numbers, see variable `basic-line-number-cols'. The default value
;; is 0, which means not using line numbers at all.
;;
;; Formatting is also affected by the customizable variables
;; `basic-delete-trailing-whitespace' and `delete-trailing-lines'
;; (from simple.el).

;;; Change Log:

;;  0.3.0  2017-??-??  Auto-numbering support.
;;                     Thanks to Peder O. Klingenberg.
;;  0.2.0  2017-10-27  Format region/buffer.
;;  0.1.3  2017-10-11  Even more syntax highlighting.
;;  0.1.2  2017-10-04  More syntax highlighting.
;;  0.1.1  2017-10-02  Fixed review comments and autoload problems.
;;  0.1.0  2017-09-28  Initial version.

;;; Code:

(require 'seq)

;; ----------------------------------------------------------------------------
;; Customization:
;; ----------------------------------------------------------------------------

(defgroup basic nil
  "Major mode for editing BASIC code."
  :link '(emacs-library-link :tag "Source File" "basic-mode.el")
  :group 'languages)

(defcustom basic-mode-hook nil
  "*Hook run when entering BASIC mode."
  :type 'hook
  :group 'basic)

(defcustom basic-indent-offset 4
  "*Specifies the indentation offset for `basic-indent-line'.
Statements inside a block are indented this number of columns."
  :type 'integer
  :group 'basic)

(defcustom basic-line-number-cols 0
  "*Specifies the number of columns to allocate to line numbers.
This number should include the single space between the line number and
the actual code. Set this variable to 0 if you do not use line numbers."
  :type 'integer
  :group 'basic)

(defcustom basic-delete-trailing-whitespace 't
  "*Delete trailing whitespace while formatting code."
  :type 'boolean
  :group 'basic)

(defcustom basic-auto-number nil
  "*Specifies auto-numbering increments.
If `nil', auto-numbering is turned off.  If not `nil', this should be an
integer defining the increment between line numbers, 10 is a traditional
choice."
  :type '(choice (const :tag "Off" nil)
		 integer)
  :group 'basic)

(defcustom basic-renumber-increment 10
  "*Default auto-numbering increment."
  :type 'integer
  :group 'basic)

;; ----------------------------------------------------------------------------
;; Variables:
;; ----------------------------------------------------------------------------

(defconst basic-mode-version "0.3.0-SNAPSHOT"
  "The current version of `basic-mode'.")

(defconst basic-increase-indent-keywords-bol
  (regexp-opt '("do" "for" "repeat" "sub" "while")
              'symbols)
  "Regexp string of keywords that increase indentation.
These keywords increase indentation when found at the
beginning of a line.")

(defconst basic-increase-indent-keywords-eol
  (regexp-opt '("else" "then")
              'symbols)
  "Regexp string of keywords that increase indentation.
These keywords increase indentation when found at the
end of a line.")

(defconst basic-decrease-indent-keywords-bol
  (regexp-opt '("else" "elseif" "endif" "end" "loop" "next" "until" "wend")
              'symbols)
  "Regexp string of keywords that decrease indentation.
These keywords decrease indentation when found at the
beginning of a line.")

(defconst basic-comment-and-string-faces
  '(font-lock-comment-face font-lock-comment-delimiter-face font-lock-string-face)
  "List of font-lock faces used for comments and strings.")

(defconst basic-comment-regexp
  "\\_<rem\\_>.*$"
  "Regexp string that matches a comment until the end of the line.")

(defconst basic-linenum-regexp
  "^[ \t]*\\([0-9]+\\)"
  "Regexp string of symbols to highlight as line numbers.")

(defconst basic-constant-regexp
  (regexp-opt '("false" "true")
              'symbols)
  "Regexp string of symbols to highlight as constants.")

(defconst basic-function-regexp
  (regexp-opt '("abs" "asc" "atn" "chr$" "command$" "cos" "exp" "fix"
                "instr" "int" "lcase$" "len" "left$" "log" "log10" "mid$"
                "pi" "right$" "rnd" "sgn" "sin" "sqr" "str$" "tab" "tan"
                "ucase$" "usr" "val")
              'symbols)
  "Regexp string of symbols to highlight as functions.")

(defconst basic-builtin-regexp
  (regexp-opt '("and" "cls" "data" "dim" "input" "let" "mat" "mod" "not" "or"
                "peek" "poke" "print" "read" "restore" "troff" "tron" "xor")
              'symbols)
  "Regexp string of symbols to highlight as builtins.")

(defconst basic-keyword-regexp
  (regexp-opt '("call" "def" "do" "else" "elseif" "end" "endif" "error" "exit"
                "fn" "for" "gosub" "goto" "if" "loop" "next" "on" "step"
                "repeat" "return" "sub" "then" "to" "until" "wend" "while")
              'symbols)
  "Regexp string of symbols to highlight as keywords.")

(defconst basic-font-lock-keywords
  (list (list basic-comment-regexp 0 'font-lock-comment-face)
        (list basic-linenum-regexp 0 'font-lock-constant-face)
        (list basic-constant-regexp 0 'font-lock-constant-face)
        (list basic-keyword-regexp 0 'font-lock-keyword-face)
        (list basic-function-regexp 0 'font-lock-function-name-face)
        (list basic-builtin-regexp 0 'font-lock-builtin-face))
  "Describes how to syntax highlight keywords in `basic-mode' buffers.")

;; ----------------------------------------------------------------------------
;; Indentation:
;; ----------------------------------------------------------------------------

(defun basic-indent-line ()
  "Indent the current line of code, see function `basic-calculate-indent'."
  (interactive)
  ;; If line needs indentation
  (when (or (not (basic-line-number-indented-correctly-p))
            (not (basic-code-indented-correctly-p)))
    (let* ((original-col (- (current-column) basic-line-number-cols))
           (original-indent-col (basic-current-indent))
           (calculated-indent-col (basic-calculate-indent)))
      (basic-indent-line-to calculated-indent-col)
      ;; Move point to a good place after indentation
      (goto-char (+ (point-at-bol)
                    calculated-indent-col
                    (max (- original-col original-indent-col) 0)
                    basic-line-number-cols)))))

(defun basic-calculate-indent ()
  "Calculate the indent for the current line of code.
The current line is indented like the previous line, unless inside a block.
Code inside a block is indented `basic-indent-offset' extra characters."
  (let ((previous-indent-col (basic-previous-indent))
        (increase-indent (basic-increase-indent-p))
        (decrease-indent (basic-decrease-indent-p)))
    (max 0 (+ previous-indent-col
              (if increase-indent basic-indent-offset 0)
              (if decrease-indent (- basic-indent-offset) 0)))))

(defun basic-comment-or-string-p ()
  "Return non-nil if point is in a comment or string."
  (let ((faces (get-text-property (point) 'face)))
    (unless (listp faces)
      (setq faces (list faces)))
    (seq-some (lambda (x) (memq x faces)) basic-comment-and-string-faces)))

(defun basic-code-search-backward ()
  "Search backward from point for a line containing code."
  (beginning-of-line)
  (re-search-backward "[^ \t\n\"']" nil t)
  (while (and (not (bobp)) (basic-comment-or-string-p))
    (re-search-backward "[^ \t\n\"']" nil t)))

(defun basic-match-symbol-at-point-p (regexp)
  "Return non-nil if the symbol at point does match REGEXP."
  (let ((symbol (symbol-at-point))
        (case-fold-search t))
    (when symbol
      (string-match regexp (symbol-name symbol)))))

(defun basic-increase-indent-p ()
  "Return non-nil if indentation should be increased.
Some keywords trigger indentation when found at the end of a line,
while other keywords do it when found at the beginning of a line."
  (save-excursion
    (basic-code-search-backward)
    (unless (bobp)
      ;; Keywords at the end of the line
      (if (basic-match-symbol-at-point-p basic-increase-indent-keywords-eol)
          't
        ;; Keywords at the beginning of the line
        (beginning-of-line)
        (re-search-forward "[^0-9 \t\n]" (point-at-eol) t)
        (basic-match-symbol-at-point-p basic-increase-indent-keywords-bol)))))

(defun basic-decrease-indent-p ()
  "Return non-nil if indentation should be decreased.
Some keywords trigger un-indentation when found at the beginning
of a line, see `basic-decrease-indent-keywords-bol'."
  (save-excursion
    (beginning-of-line)
    (re-search-forward "[^0-9 \t\n]" (point-at-eol) t)
    (basic-match-symbol-at-point-p basic-decrease-indent-keywords-bol)))

(defun basic-current-indent ()
  "Return the indent column of the current code line.
The columns allocated to the line number are ignored."
  (save-excursion
    (beginning-of-line)
    ;; Skip line number and spaces
    (skip-chars-forward "0-9 \t" (point-at-eol))
    (let ((indent (- (point) (point-at-bol))))
      (- indent basic-line-number-cols))))

(defun basic-previous-indent ()
  "Return the indent column of the previous code line.
The columns allocated to the line number are ignored.
If the current line is the first line, then return 0."
  (save-excursion
    (basic-code-search-backward)
    (cond ((bobp) 0)
          (t (basic-current-indent)))))

(defun basic-line-number-indented-correctly-p ()
  "Return non-nil if line number is indented correctly.
If there is no line number, also return non-nil."
  (save-excursion
    (if (not (basic-has-line-number-p))
        t
      (beginning-of-line)
      (skip-chars-forward " \t" (point-at-eol))
      (skip-chars-forward "0-9" (point-at-eol))
      (and (looking-at "[ \t]")
           (= (point) (+ (point-at-bol) basic-line-number-cols -1))))))

(defun basic-code-indented-correctly-p ()
  "Return non-nil if code is indented correctly."
  (save-excursion
    (let ((original-indent-col (basic-current-indent))
          (calculated-indent-col (basic-calculate-indent)))
      (= original-indent-col calculated-indent-col))))

(defun basic-has-line-number-p ()
  "Return non-nil if the current line has a line number."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t" (point-at-eol))
    (looking-at "[0-9]")))

(defun basic-remove-line-number ()
  "Remove and return the line number of the current line.
After calling this function, the current line will begin with the first
non-blank character after the line number."
  (if (not (basic-has-line-number-p))
      ""
    (beginning-of-line)
    (re-search-forward "\\([0-9]+\\)" (point-at-eol) t)
    (let ((line-number (match-string-no-properties 1)))
      (delete-region (point-at-bol) (match-end 1))
      line-number)))

(defun basic-format-line-number (number)
  "Format NUMBER as a line number."
  (if (= basic-line-number-cols 0)
      number
    (format (concat "%" (number-to-string (- basic-line-number-cols 1)) "s ") number)))

(defun basic-indent-line-to (column)
  "Indent current line to COLUMN, also considering line numbers."
  ;; Remove line number
  (let* ((line-number (basic-remove-line-number))
         (formatted-number (basic-format-line-number line-number)))
    ;; Indent line
    (indent-line-to column)
    ;; Add line number again
    (beginning-of-line)
    (insert formatted-number)))

;; ----------------------------------------------------------------------------
;; Formatting:
;; ----------------------------------------------------------------------------

(defun basic-delete-trailing-whitespace-line ()
  "Delete any trailing whitespace on the current line."
  (beginning-of-line)
  (when (re-search-forward "\\s-*$" (line-end-position) t)
    (replace-match "")))

(defun basic-format-code ()
  "Format all lines in region, or entire buffer if region is not active.
Indent lines, and also remove any trailing whitespace if the
variable `basic-delete-trailing-whitespace' is non-nil.

If this command acts on the entire buffer it also deletes all
trailing lines at the end of the buffer if the variable
`delete-trailing-lines' is non-nil."
  (interactive)
  (let* ((entire-buffer (not (use-region-p)))
         (point-start (if (use-region-p) (region-beginning) (point-min)))
         (point-end (if (use-region-p) (region-end) (point-max)))
         (line-end (line-number-at-pos point-end)))

    (save-excursion
      ;; Don't format last line if region ends on first column
      (goto-char point-end)
      (when (= (current-column) 0)
        (setq line-end (1- line-end)))

      ;; Loop over all lines and format
      (goto-char point-start)
      (while (and (<= (line-number-at-pos) line-end) (not (eobp)))
        (basic-indent-line)
        (when basic-delete-trailing-whitespace
          (basic-delete-trailing-whitespace-line))
        (forward-line))

      ;; Delete trailing empty lines
      (when (and entire-buffer
                 delete-trailing-lines
                 (= (point-max) (1+ (buffer-size)))) ;; Really end of buffer?
        (goto-char (point-max))
        (backward-char)
        (while (eq (char-before) ?\n)
          (delete-char -1))
        ))))

;; ----------------------------------------------------------------------------
;; Line numbering:
;; ----------------------------------------------------------------------------

(defun basic-current-line-number ()
  (save-excursion
    (if (not (basic-has-line-number-p))
	nil
      (beginning-of-line)
      (re-search-forward "\\([0-9]+\\)" (point-at-eol) t)
      (let ((line-number (match-string-no-properties 1)))
	(string-to-number line-number)))))

(defun basic-newline-and-number ()
  "Insert a newline and indent to the proper level.
If the current line starts with a line number, and auto-numbering is
turned on (see `basic-auto-number'), insert the next automatic number
in the beginning of the line.

If opening a new line between two numbered lines, and the next
automatic number would be >= the line number of the existing next
line, we try to find a midpoint between the two existing lines
and use that as the next number.  If no more unused line numbers
are available between the existing lines, just increment by one,
even if that creates overlaps."
  (interactive)
  (let* ((current-line-number (basic-current-line-number))
	 (next-line-number (save-excursion
			     (end-of-line)
			     (and (forward-word 1)
				  (basic-current-line-number))))
	 (new-line-number (and current-line-number
			       basic-auto-number
			       (+ current-line-number basic-auto-number))))
    (basic-indent-line)
    (newline)
    (when new-line-number
      (when (and next-line-number
		 (<= next-line-number
		     new-line-number))
	(setq new-line-number
	      (+ current-line-number
		 (truncate (- next-line-number current-line-number)
			   2)))
	(when (= new-line-number current-line-number)
	  (setq new-line-number (1+ new-line-number))))
      (insert (int-to-string new-line-number)))
    (basic-indent-line)))

;; ----------------------------------------------------------------------------
;; BASIC mode:
;; ----------------------------------------------------------------------------

(defvar basic-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-f" 'basic-format-code)
    (define-key map "\r" 'basic-newline-and-number)
    map)
  "Keymap used in ‘basic-mode'.")

(defvar basic-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_   "w   " table)
    (modify-syntax-entry ?\.  "w   " table)
    (modify-syntax-entry ?'   "<   " table)
    (modify-syntax-entry ?\n  ">   " table)
    (modify-syntax-entry ?\^m ">   " table)
    table)
  "Syntax table used while in ‘basic-mode'.")

;;;###autoload
(define-derived-mode basic-mode prog-mode "Basic"
  "Major mode for editing BASIC code.
Commands:
TAB indents for BASIC code.

\\{basic-mode-map}"
  :group 'basic
  (setq-local indent-line-function 'basic-indent-line)
  (setq-local comment-start "'")
  (setq-local font-lock-defaults '(basic-font-lock-keywords nil t))
  (unless font-lock-mode
    (font-lock-mode 1)))

;;;###autoload (add-to-list 'auto-mode-alist '("\\.bas\\'" . basic-mode))

;; ----------------------------------------------------------------------------

(provide 'basic-mode)

;;; basic-mode.el ends here
