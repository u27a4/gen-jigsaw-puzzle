(script-fu-register
  "script-fu-gen-jigsaw-puzzle"
  "Jigsaw puzzle"
  "Generate jigsaw puzzle pieces and frame"
  "u27a4"
  ""
  "May 2020"
  ""
  SF-IMAGE      "Image"             0
  SF-DRAWABLE   "Drawale"           0
  SF-DIRNAME    "Output Directory"  ""
  SF-ADJUSTMENT "Frame Weight"      '(50 1 500 1 1 0 SF-SLIDER)
  SF-ADJUSTMENT "Number of Columns" '(9 1 20 1 1 0 SF-SLIDER)
  SF-ADJUSTMENT "Number of Rows"    '(7 1 20 1 1 0 SF-SLIDER)
)

(script-fu-menu-register
  "script-fu-gen-jigsaw-puzzle"
  "<Image>/File/Create"
)

(define (script-fu-gen-jigsaw-puzzle
    img main-layer outdir frame-width num-rows num-columns)
  (let*
    (
      (frame-height frame-width)
      (radius (/ frame-width 2))
      (width (car (gimp-image-width img)))
      (height (car (gimp-image-height img)))
      (inner-width (- width (* frame-width 2)))
      (inner-height (- height (* frame-height 2)))
      (jigsaw-layer (car (gimp-layer-new img inner-width inner-height
        RGBA-IMAGE "jigsaw-pattern" 100 NORMAL-MODE)))
      (output (open-output-file (string-append outdir "/output.json")))
    )
    (gimp-image-undo-group-start img)

    ; プロパティファイルにパズル全般に関する項目を追加
    (display "{\n" output)
    (display "  \"width\": " output)
    (display (string-append (number->string width) ",\n") output)
    (display "  \"height\": " output)
    (display (string-append (number->string height) ",\n") output)
    (display "  \"frameWidth\": " output)
    (display (string-append (number->string frame-width) ",\n") output)
    (display "  \"frameHeight\": " output)
    (display (string-append (number->string frame-height) ",\n") output)
    (display "  \"numRows\": " output)
    (display (string-append (number->string num-rows) ",\n") output)
    (display "  \"numColumns\": " output)
    (display (string-append (number->string num-columns) ",\n") output)
    (display "  \"pieces\": [\n    " output)

    ; ジグソーパズルのパターンを生成
    (gimp-image-add-layer img jigsaw-layer -1)
    (gimp-layer-translate jigsaw-layer frame-width frame-height)
    (gimp-image-select-round-rectangle img CHANNEL-OP-REPLACE
      frame-width frame-height inner-width inner-height radius radius)
    (gimp-context-set-background '(255 255 255))
    (gimp-edit-fill jigsaw-layer BACKGROUND-FILL)
    (plug-in-jigsaw RUN-NONINTERACTIVE img jigsaw-layer
      num-rows num-columns 1 0 0)

    ; ピースを生成
    (let*
      (
        (tile-width (/ inner-width num-rows))
        (tile-height(/ inner-height num-columns))
        (tile-wrap-width (* tile-width 2))
        (tile-wrap-height (* tile-height 2))
        (tile-half-width (/ tile-width 2))
        (tile-half-height (/ tile-height 2))
        (piece-layer '())
        (filename "")
        (filepath "")
        (ix 0) (iy 0) (px 0) (py 0)
      )

      ; パターンから各ピースを生成
      (while (< iy num-columns)
        (set! py (+ tile-half-height (* tile-height iy)))
        (while (< ix num-rows)
          (set! px (+ tile-half-width (* tile-width ix)))
          (set! piece-layer (car (gimp-layer-new img
            tile-wrap-width tile-wrap-height
            RGBA-IMAGE "piece" 100 NORMAL-MODE)))
          (gimp-image-add-layer img piece-layer -1)
          (gimp-layer-translate piece-layer
            (- (+ frame-width (* tile-width ix)) tile-half-width)
            (- (+ frame-height (* tile-height iy)) tile-half-height))

          (gimp-fuzzy-select jigsaw-layer px py 1
            CHANNEL-OP-REPLACE TRUE FALSE 0 FALSE)
          (gimp-edit-copy main-layer)
          (gimp-floating-sel-to-layer (car (
            gimp-edit-paste piece-layer TRUE)))
          (gimp-selection-none img)

          (set! piece-layer (car (gimp-image-get-active-layer img)))
          (script-fu-drop-shadow img piece-layer 2 2 6 '(0 0 0) 60 TRUE)
          (set! piece-layer (car (gimp-image-merge-down
            img piece-layer EXPAND-AS-NECESSARY)))
          (set! piece-layer (car (gimp-image-merge-down
            img piece-layer EXPAND-AS-NECESSARY)))

          ; 画像として保存
          (set! filename (string-append "piece_"
            (number->string ix) "_" (number->string iy) ".png"))
          (set! filepath (string-append outdir "/" filename))
          (file-png-save-defaults RUN-NONINTERACTIVE img
            piece-layer filepath filepath)

          (gimp-image-remove-layer img piece-layer)

          ; プロパティファイルにピースの項目を追加
          (display "{\n" output)
          (display "      \"filename\": \"" output)
          (display (string-append filename "\",\n") output)
          (display "      \"position\": {\n" output)
          (display "        \"x\": " output)
          (display (string-append (number->string px) ",\n") output)
          (display "        \"y\": " output)
          (display (string-append (number->string py) "\n") output)
          (display "      }\n" output)
          (display "    }" output)
          (if (< (* (+ ix 1) (+ iy 1)) (* num-rows num-columns))
            (display ", " output)
          )

          (set! ix (+ ix 1))
        )
        (set! iy (+ iy 1))
        (set! ix 0)
      )
    )

    ; フレームを生成
    (let*
      (
        (bg-opacity 90)
        (frame-layer (car (gimp-layer-copy main-layer TRUE)))
        (frame-bg-layer '())
      )

      ; フレーム背景の生成
      (set! frame-bg-layer (car (gimp-layer-copy main-layer TRUE)))
      (gimp-image-add-layer img frame-bg-layer -1)
      (gimp-selection-all img)
      (gimp-image-select-round-rectangle
        img CHANNEL-OP-SUBTRACT 0 0 width height radius radius)
      (gimp-edit-clear frame-bg-layer)
      (gimp-selection-none img)
      (set! frame-bg-layer (car (gimp-layer-copy jigsaw-layer TRUE)))
      (gimp-image-add-layer img frame-bg-layer -1)
      (plug-in-gauss RUN-NONINTERACTIVE img frame-bg-layer 2.0 2.0 0)
      (gimp-layer-set-opacity frame-bg-layer bg-opacity)
      (set! frame-bg-layer (car (gimp-image-merge-down
        img frame-bg-layer EXPAND-AS-NECESSARY)))

      ; フレームの生成
      (gimp-image-add-layer img frame-layer -1)
      (gimp-selection-all img)
      (gimp-image-select-round-rectangle
        img CHANNEL-OP-SUBTRACT 0 0 width height radius radius)
      (gimp-edit-clear frame-layer)

      (gimp-image-select-round-rectangle
        img CHANNEL-OP-REPLACE frame-width frame-height
        inner-width inner-height radius radius)
      (gimp-context-set-background '(50 50 50))
      (gimp-edit-fill frame-layer BACKGROUND-FILL)
      (gimp-edit-clear frame-layer)
      (gimp-selection-none img)
      (script-fu-drop-shadow img frame-layer 2 2 15 '(0 0 0) 60 TRUE)

      ; 画像として保存
      (gimp-drawable-set-visible main-layer FALSE)
      (gimp-drawable-set-visible jigsaw-layer FALSE)
      (set! frame-layer (car (gimp-image-merge-down
        img frame-layer EXPAND-AS-NECESSARY)))
      (set! frame-layer (car (gimp-image-merge-down
        img frame-layer EXPAND-AS-NECESSARY)))
      (file-png-save-defaults RUN-NONINTERACTIVE img frame-layer
        (string-append outdir "/frame.png")
        (string-append outdir "/frame.png"))

      ; 片付け
      (gimp-image-remove-layer img frame-layer)
      (gimp-image-remove-layer img jigsaw-layer)
      (gimp-image-resize-to-layers img)
      (gimp-drawable-set-visible main-layer TRUE)
    )

    ; ouput.json
    (display "\n  ]\n" output)
    (display "}" output)
    (close-output-port output)

    (gimp-displays-flush)
    (gimp-image-undo-group-end img)
  )
)