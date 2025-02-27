module Ocarina.Example.Docs.FixFan.Fan0 where

import Prelude

import Bolson.Core (envy)
import Deku.Core (Nut)
import Deku.Pursx (makePursx')
import Effect (Effect)
import FRP.Event (Event)
import Ocarina.Control (bandpass_, fan1, gain_, loopBuf)
import Ocarina.Core (bangOn)
import Ocarina.Example.Docs.Types (CancelCurrentAudio, Page, SingleSubgraphEvent)
import Ocarina.Example.Docs.Util (audioWrapper)
import Ocarina.Interpret (decodeAudioDataFromUri)
import Ocarina.Run (run2)
import Type.Proxy (Proxy(..))

px =
  Proxy    :: Proxy         """<div>
  <pre><code>run2_
  [ fan1 (loopBuf buf bangOn)
      \b _ -> gain_ 0.8
        [ bandpass_ { frequency: 400.0, q: 1.0 } [ b ]
        , bandpass_ { frequency: 880.0, q: 5.0 } [ b ]
        , bandpass_ { frequency: 1200.0, q: 10.0 } [ b ]
        , bandpass_ { frequency: 2000.0, q: 20.0 } [ b ]
        , bandpass_ { frequency: 3000.0, q: 30.0 } [ b ]
        ]
  ]</code></pre>

  @ai0@
  </div>
"""

fan0 :: CancelCurrentAudio -> (Page -> Effect Unit) -> Event SingleSubgraphEvent -> Nut
fan0 ccb _ ev = makePursx' (Proxy :: _ "@") px
  { ai0:
      ( audioWrapper ev ccb (\ctx -> decodeAudioDataFromUri ctx "https://freesound.org/data/previews/320/320873_527080-hq.mp3")
          \ctx buf -> run2 ctx
            [ fan1 (loopBuf buf bangOn)
                \b -> gain_ 0.8
                  [ bandpass_ { frequency: 400.0, q: 1.0 } [ b ]
                  , bandpass_ { frequency: 880.0, q: 5.0 } [ b ]
                  , bandpass_ { frequency: 1200.0, q: 10.0 } [ b ]
                  , bandpass_ { frequency: 2000.0, q: 20.0 } [ b ]
                  , bandpass_ { frequency: 3000.0, q: 30.0 } [ b ]
                  ]
            ]

      )
  }

{-
fan (loopBuf buf bangOn)
  \b -> gain_ 0.8
    ( bandpass_ { frequency: 400.0, q: 1.0 } [b]
    ~ bandpass_ { frequency: 880.0, q: 5.0 } [b]
    ~ bandpass_ { frequency: 1200.0, q: 10.0 } [b]
    ~ bandpass_ { frequency: 2000.0, q: 20.0 } [b]
    ! bandpass_ { frequency: 3000.0, q: 30.0 } [b]
    )


  -}