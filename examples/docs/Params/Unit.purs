module Ocarina.Example.Docs.Params.Unit where

import Prelude

import Data.Foldable (oneOf)
import Deku.Core (Nut)
import Deku.Pursx ((~~))
import Effect (Effect)
import FRP.Event (Event)
import Ocarina.Control (constant, gain_, loopBuf, lowpass_, squareOsc)
import Ocarina.Core (bangOn, c1)
import Ocarina.Example.Docs.Types (CancelCurrentAudio, Page, SingleSubgraphEvent)
import Ocarina.Example.Docs.Util (audioWrapper)
import Ocarina.Interpret (decodeAudioDataFromUri)
import Ocarina.Properties (playbackRate)
import Ocarina.Run (run2)
import Type.Proxy (Proxy(..))

px =
  Proxy    :: Proxy         """<section>
  <h2>Audio Units</h2>
  <p>In my humble opinion, the summit of Web Audio programming is when audio units control the audio parameters of other audio units. This allows for a form of radical experimentation that is difficult in many other frameworks. <a href="https://www.w3.org/TR/webaudio/#ModularRouting">Nearly any audio parameter</a> can be automated this way.</p>

  <p>To control an audio parameter with an audio unit, use the <code>AudioUnit</code> constructor. You can also use a <code>Node D1 l p</code>. If your node is for an arbitrary number of channels, make sure to coerce it to mono using the <code>c1</code> function, as in the example below.</p>

  <pre><code>\ctx buf -> run2 ctx
  [ loopBuf buf OneOf.do
      bangOn
      pure
        $ playbackRate
        $ c1
            ( gain_ 1.0
                [ constant 1.0 bangOn
                , gain_ 0.2 (lowpass_ 100.0 (squareOsc 50.0 bangOn))
                ]
            )
      )
  ]
</code></pre>

  ~unitEx~
  </section>
"""

unitEx :: CancelCurrentAudio -> (Page -> Effect Unit) -> Event SingleSubgraphEvent -> Nut
unitEx ccb _ ev = px ~~
  { unitEx:
      ( audioWrapper ev ccb (\ctx -> decodeAudioDataFromUri ctx "https://freesound.org/data/previews/320/320873_527080-hq.mp3")
          \ctx buf -> run2 ctx
            [ loopBuf buf
                ( oneOf
                    [ bangOn
                    , pure
                        $ playbackRate
                        $ c1
                            ( gain_ 1.0
                                [ constant 1.0 bangOn
                                , gain_ 0.2 [lowpass_ 100.0 [squareOsc 50.0 bangOn]]
                                ]
                            )
                    ]
                )
            ]
      )
  }