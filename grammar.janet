(use ./util)

# TODO: don't be loose and variadic
(defn- header [hashes & s] [:header (length hashes) s])
(defn- node [kw] (fn [& s] [kw s]))

# TODO: do this in PEG. or idk, peg is kinda hard, being greedy and all
(defn- link-and-text [inside]
  (var ret [])
  # this could be airier and less duplicated
  (cond
    (string/find "|" inside) (do
                               (def parts (string/split "|" inside))
                               (set ret [(get (array/slice parts -2 -1) 0) (string/join (array/slice parts 0 -2))]))
    (do
      (def parts (string/split " " inside))
      (set ret [(get (array/slice parts -2 -1) 0) (string/join (array/slice parts 0 -2) " ")])))
  ret)

# MAYBE: do whitespace in peg
(defn meta [k v] [:set (string/trim k) (string/trim v)])
(defn image [inside]
  [:image ;(link-and-text inside)])
(defn link [inside]
  [:link ;(link-and-text inside)])

# needs trailing newline
# super fecking out of sync with the wip spec ideas
(def document ~{# preprocessing changes these to always be \n, maybe let it just be \n
                :nl (+ "\n" "\r" "\r\n")
                # The basics
                :char (if-not :nl 1)
                :chars (some :char)
                :wrapping (choice :bold-wrap :italic-wrap :code-wrap)

                :normalchar (if-not (choice :nl :wrapping) 1)
                :normaltext (some :normalchar)

                # Styling
                :styling (choice :image :link :code :italic :bold)

                :bold-wrap (choice "*")
                :in-bold (if (to :bold-wrap) :text)
                :bold (* :bold-wrap (replace :in-bold ,(node :bold)) :bold-wrap)

                :italic-wrap (choice "_")
                :in-italic (if (to :italic-wrap) :text)
                # : not allowed before italic, to prevent URLs from becoming italic
                :italic (* :italic-wrap (replace :in-italic ,(node :italic)) :italic-wrap)

                :code-wrap (choice "`")
                :in-code (capture (some (if-not :code-wrap 1)))
                :code (* :code-wrap (replace :in-code ,(node :code)) :code-wrap)

                :link (replace (* "[" (capture (to "]")) "]") ,link)
                # XXX: image/img not used in spec but here. remove?
                # TODO: make image a line element. inline images are html-specific
                :image (replace (* (choice "image" "img" "!") "[" (capture (to "]")) "]") ,image)

                :text (some (choice :styling (capture :normaltext)))

                # Structural

                # TODO: remove html terminology
                :in-pre-code (any (if-not "===" (* :chars "\n")))
                :pre-code (* "===\n" (replace (capture :in-pre-code) ,(node :multiline-code)) "===")

                # XXX: maybe allow arbitrary depth headers and make html trunc it. cos html aint god (roff does any depth)
                :hashes (between 1 6 "#")
                :header (replace (* (capture :hashes) (any " ") :text) ,header)
                :title (replace (* "=#" (any " ") (capture :chars)) ,(fn [ast] [:set "title" ast]))

                # TODO: styled
                :quote (replace (* "|" (any " ") (capture :chars)) ,(node :blockquote))
                # TODO: styled
                :in-multiline-quote (any (if-not `"""` (* :chars "\n")))
                :multiline-quote (* "\"\"\"\n" (replace (capture :in-multiline-quote) ,(node :blockquote)) `"""`)

                :hr (replace (at-least 2 "-") [:break])

                # Styled paragraph into lines
                # XXX: We need to insert a space after every line, where to do that? 
                :paragraph (replace (some (* :text (replace "\n" " "))) ,(node :paragraph))

                :li (* (choice :list (replace (some (if-not (choice :nl (set "[]{}")) :text)) ,(fn [& x] [;x])) "") :nl)
                :ul (* "[" (? "\n") (replace (some :li) ,(node :unordered-list)) "]")
                :ol (* "{" (? "\n") (replace (some :li) ,(node :ordered-list)) "}")
                :list (choice :ol :ul)

                # TODO: styled text in tables
                # XXX: how should we handle 1-column rows? for now, let's allow them if they have a delim at the end
                :table (replace (* "#" (capture (to "{") :delim) "{\n"
                                   (some
                                     # row
                                     (cmt
                                       (*
                                         (some (*
                                                 (replace (capture (some (if-not (choice :nl (backmatch :delim)) 1))) ,(fn [x] [x]))
                                                 (backmatch :delim)))
                                         (? (replace (capture (some (if-not (choice :nl (backmatch :delim)) 1))) ,(fn [x] [x])))
                                         "\n"
                                         # (capture (capture (some (if-not (choice :nl (backmatch :delim)) 1))))
) ,array))
                                   "}") ,(fn [_ & rows] [:table rows]))

                :metadata (choice :single-metadata :multi-metadata)
                :single-metadata (cmt (* "@{" (capture (if-not (* "\n" (some 1)) (to "="))) "=" (capture (to "}")) "}\n") ,meta)
                :multi-metadata (* "@{\n"
                                   (some
                                     (cmt
                                       (*
                                         (capture (to "=")) "=" (capture (to "\n")) "\n") ,meta))
                                   "}")

                # XXX: maybe move metadata lines into here
                :line (choice :title :header :quote :hr "")
                :element (choice :metadata :table :multiline-quote :pre-code :list (* :line "\n") :paragraph)
                :main (some :element)})
