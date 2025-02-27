module Ocarina.Example.Docs.AudioUnits.LoopBuf where

import Prelude

import Bolson.Core (envy)
import Deku.Core (Nut)
import Deku.Pursx (makePursx')
import Effect (Effect)
import FRP.Event (Event)
import Ocarina.Control (loopBuf)
import Ocarina.Core (bangOn)
import Ocarina.Example.Docs.Types (CancelCurrentAudio, Page, SingleSubgraphEvent)
import Ocarina.Example.Docs.Util (audioWrapper)
import Ocarina.Interpret (decodeAudioDataFromUri)
import Ocarina.Run (run2)
import Type.Proxy (Proxy(..))

px =
  Proxy    :: Proxy         """<section>
  <h2 id="loopbuf">Looping buffer</h2>

  <p>A <a href="https://developer.mozilla.org/en-US/docs/Web/API/AudioBufferSourceNode">looping buffer</a> is buffered audio that loops. The buffered audio is usually a sound file, but it'll play anything you write to a buffer. Like in the Web Audio API, you can set the buffer's start and end and optionally its duration.</p>

  <pre><code>\buf -> run2_
  [ loopBuf
      { buffer: buf
      , playbackRate: 0.5
      , loopStart: 0.1
      , loopEnd: 0.6
      }
      bangOn
  , loopBuf
      { buffer: buf
      , playbackRate: 1.0
      , loopStart: 0.5
      , loopEnd: 1.2
      }
      bangOn
  , loopBuf
      { buffer: buf
      , playbackRate: 1.7
      }
      bangOn
  ]</code></pre>

  @loopBuf@
  </section>
"""

loopBufEx
  :: CancelCurrentAudio -> (Page -> Effect Unit) -> Event SingleSubgraphEvent -> Nut
loopBufEx ccb _ ev = makePursx' (Proxy :: _ "@") px
  { loopBuf:
      ( audioWrapper ev ccb (\ctx -> decodeAudioDataFromUri ctx "https://freesound.org/data/previews/100/100981_1234256-lq.mp3")
          \ctx buf -> run2 ctx
            [ loopBuf
                { buffer: buf
                , playbackRate: 0.5
                , loopStart: 0.1
                , loopEnd: 0.6
                }
                bangOn
            , loopBuf
                { buffer: buf
                , playbackRate: 1.0
                , loopStart: 0.5
                , loopEnd: 1.2
                }
                bangOn
            , loopBuf
                { buffer: buf
                , playbackRate: 1.7
                }
                bangOn
            ]
      )
  }