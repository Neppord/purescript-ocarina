module Ocarina.Example.Docs.Effects.FoldEx where

import Prelude

import Control.Alt ((<|>))
import Data.Foldable (oneOf, oneOfMap)
import Data.Number (pi, sin)
import Data.Tuple.Nested ((/\))
import Data.Vec ((+>))
import Data.Vec as V
import Deku.Attribute (attr, cb, (:=))
import Deku.Control (text, text_)
import Deku.Core (Nut, vbussed)
import Deku.DOM as D
import Deku.Pursx ((~~))
import Effect (Effect)
import FRP.Behavior (sampleBy, sample_, step)
import FRP.Event (Event, fold, mapAccum, memoize, sampleOnRight)
import FRP.Event.Animate (animationFrameEvent)
import FRP.Event.VBus (V)
import Ocarina.Clock(withACTime)
import Ocarina.Control (gain, periodicOsc)
import Ocarina.Core (AudioNumeric(..), _linear, bangOn)
import Ocarina.Example.Docs.Types (CancelCurrentAudio, Page, SingleSubgraphEvent(..), SingleSubgraphPusher)
import Ocarina.Interpret (close, constant0Hack, context)
import Ocarina.Math (calcSlope)
import Ocarina.Properties as P
import Ocarina.Run (run2e)
import Type.Proxy (Proxy(..))

px =
  Proxy    :: Proxy      """<section>
  <h2>Fold</h2>

  <p>The type of <code>fold</code> is:</p>

  <pre><code>fold
    :: forall event a b
    . IsEvent event
    => (a -> b -> b)
    -> event a
    -> b
    -> event b</code></pre>

  <p>Fold starts with some initial state <code>b</code> and, based on incoming events, allows you to change the state.</p>

  <p>One way <code>fold</code> is useful is to retain when certain actions happen. In the following example, we use <code>requestAnimationFrame</code> to animate the audio and we use four <code>fold</code>-s to store the ambitus and velocity of both vibrato and tremolo.</p>

  <pre><code>~txt~</code></pre>

  ~empl~

  <p><code>fold</code> is so powerful because it allows us to localize state to <i>any</i> event. In the example above, instead of having a global state, our two folds allow for two <i>ad hoc</i> local states.</p>

</section>"""

type Cbx = V (cbx0 :: Unit, cbx1 :: Unit, cbx2 :: Unit, cbx3 :: Unit)

type StartStop = V (start :: Unit, stop :: Effect Unit)

type UIEvents = V
  ( startStop :: StartStop
  , cbx :: Cbx
  )

foldEx :: CancelCurrentAudio -> (Page -> Effect Unit) -> SingleSubgraphPusher -> Event SingleSubgraphEvent -> Nut
foldEx ccb _ _ ev = px ~~
  { txt: text_
      """module Main where

import Prelude

import Control.Alt ((<|>))
import QualifiedDo.OneOfMap as O
import QualifiedDo.Alt as OneOf
import Data.Tuple.Nested ((/\))
import Data.Vec ((+>))
import Data.Vec as V
import Deku.Attribute (attr, cb, (:=))
import Deku.Control (text)
import Deku.DOM as D
import Deku.Toplevel (runInBody1)
import Effect (Effect)
import FRP.Behavior (sampleBy, sample_, step)
import FRP.Event (memoize)
import FRP.Event.Animate (animationFrameEvent)
import FRP.Event.Class (fold, mapAccum, sampleOnRight)
import FRP.Event.VBus (V, vbus)
import Data.Number (pi, sin)
import Type.Proxy (Proxy(..))
import Ocarina.Clock(withACTime)
import Ocarina.Control (gain, periodicOsc)
import Ocarina.Interpret (close, constant0Hack, context)
import Ocarina.Math (calcSlope)
import Ocarina.Core (AudioNumeric(..), _linear, bangOn)
import Ocarina.Properties as P
import Ocarina.Run (run2e)

type Cbx = V (cbx0 :: Unit, cbx1 :: Unit, cbx2 :: Unit, cbx3 :: Unit)

type StartStop = V (start :: Unit, stop :: Effect Unit)

type UIEvents = V
  ( startStop :: StartStop
  , cbx :: Cbx
  )

main :: Effect Unit
main = runInBody1
  ( vbus (Proxy :: _ UIEvents) \push event -> do
      let
        startE = pure unit <|> event.startStop.start
        stopE = event.startStop.stop
        chkState e = step false $ fold (const not) e false
        cbx0 = chkState event.cbx.cbx0
        cbx1 = chkState event.cbx.cbx1
        cbx2 = chkState event.cbx.cbx2
        cbx3 = chkState event.cbx.cbx3
      D.div_
        [ D.button
            ( O.oneOfMap (map (attr D.OnClick <<< cb <<< const)) O.do
                stopE <#> (_ *> push.startStop.start unit)
                startE $> do
                  ctx <- context
                  c0h <- constant0Hack ctx
                  let
                    cevt fast b tm = mapAccum
                      ( \(oo /\ act) (pact /\ pt) ->
                          let
                            tn = pt +
                              ( (act - pact) *
                                  (if oo then fast else 1.0)
                              )
                          in
                            ((act /\ tn) /\ tn)
                      )
                      (sampleBy (/\) b tm)
                      (0.0 /\ 0.0)

                  r <- run2e ctx
                    ( memoize
                        ( map (add 0.04 <<< _.acTime)
                            $ withACTime ctx animationFrameEvent
                        )
                        \acTime ->
                          let
                            ev0 = cevt 8.0 cbx0 acTime
                            ev1 = map (if _ then 4.0 else 1.0) $ sample_ cbx1 acTime
                            ev2 = cevt 4.0 cbx2 acTime
                            ev3 = map (if _ then 4.0 else 1.0) $ sample_ cbx3 acTime
                            evs f a = sampleOnRight acTime
                              $ map ($)
                              $ sampleOnRight a
                              $ { f: _, a: _, t: _ } <$> f
                          in
                            [ gain 0.0
                                ( evs ev0 ev1 <#> \{ f, a, t } -> P.gain $ AudioNumeric
                                    { n: calcSlope 1.0 0.01 4.0 0.15 a * sin (pi * f) + 0.15
                                    , o: t
                                    , t: _linear
                                    }
                                )
                                [ periodicOsc
                                    { frequency: 325.6
                                    , spec: (0.3 +> -0.1 +> 0.7 +> -0.4 +> V.empty)
                                        /\ (0.6 +> 0.3 +> 0.2 +> 0.0 +> V.empty)
                                    }
                                    ( OneOf.do
                                        bangOn
                                        evs ev2 ev3 <#> \{ f, a, t } -> P.frequency
                                          $ AudioNumeric
                                              { n: 325.6 +
                                                  (calcSlope 1.0 3.0 4.0 15.5 a * sin (pi * f))
                                              , o: t
                                              , t: _linear
                                              }
                                    )
                                ]
                            ]
                    )
                  push.startStop.stop (r *> c0h *> close ctx)
            )
            [ text OneOf.do
                startE $> "Turn on"
                stopE $> "Turn off"
            ]
        , D.div
            ( O.oneOfMap (map (attr D.Style)) O.do
                stopE $> "display:block;"
                startE $> "display:none;"
            )
            ( map
                ( \e -> D.input
                    ( OneOf.do
                        pure (D.Xtype := "checkbox")
                        pure (D.OnClick := cb (const (e unit)))
                        startE $> (D.Checked := "false")
                    )
                    []
                )
                ([ _.cbx0, _.cbx1, _.cbx2, _.cbx3 ] <@> push.cbx)
            )
        ]
  )"""
  , empl:
      ( vbussed (Proxy :: _ UIEvents) \push event -> do
          let
            startE = pure unit <|> event.startStop.start
            stopE = event.startStop.stop
            chkState e = step false $ fold (\a _ -> not a) false e
            cbx0 = chkState event.cbx.cbx0
            cbx1 = chkState event.cbx.cbx1
            cbx2 = chkState event.cbx.cbx2
            cbx3 = chkState event.cbx.cbx3
          D.div_
            [ D.button
                [oneOfMap (map (attr D.OnClick <<< cb <<< const))
                    [ ((startE $> identity) <*> (pure (pure unit) <|> (map (\(SetCancel x) -> x) ev)) ) <#> \cncl -> do
                        cncl
                        ctx <- context
                        c0h <- constant0Hack ctx
                        let
                          cevt fast b tm = mapAccum
                            ( \ (pact /\ pt)  (oo /\ act)->
                                let
                                  tn = pt +
                                    ( (act - pact) *
                                        (if oo then fast else 1.0)
                                    )
                                in
                                  ((act /\ tn) /\ tn)
                            )
                            (0.0 /\ 0.0)
                            (sampleBy (/\) b tm)

                        r' <- run2e ctx
                          ( memoize
                              ( map (add 0.04 <<< _.acTime)
                                  $ withACTime ctx animationFrameEvent
                              )
                              \acTime ->
                                let
                                  ev0 = cevt 8.0 cbx0 acTime
                                  ev1 = map (if _ then 4.0 else 1.0) $ sample_ cbx1 acTime
                                  ev2 = cevt 4.0 cbx2 acTime
                                  ev3 = map (if _ then 4.0 else 1.0) $ sample_ cbx3 acTime
                                  evs f a = sampleOnRight acTime
                                    $ map ($)
                                    $ sampleOnRight a
                                    $ { f: _, a: _, t: _ } <$> f
                                in
                                  [ gain 0.0
                                      ( evs ev0 ev1 <#> \{ f, a, t } -> P.gain $ AudioNumeric
                                          { n: calcSlope 1.0 0.01 4.0 0.15 a * sin (pi * f) + 0.15
                                          , o: t
                                          , t: _linear
                                          }
                                      )
                                      [ periodicOsc
                                          { frequency: 325.6
                                          , spec: (0.3 +> -0.1 +> 0.7 +> -0.4 +> V.empty)
                                              /\ (0.6 +> 0.3 +> 0.2 +> 0.0 +> V.empty)
                                          }
                                          ( oneOf
                                              [ bangOn
                                              , evs ev2 ev3 <#> \{ f, a, t } -> P.frequency
                                                  $ AudioNumeric
                                                    { n: 325.6 +
                                                        (calcSlope 1.0 3.0 4.0 15.5 a * sin (pi * f))
                                                    , o: t
                                                    , t: _linear
                                                    }
                                              ]
                                          )
                                      ]
                                  ]
                          )
                        let r = r' *> c0h *> close ctx
                        ccb (r *> push.startStop.start unit) -- here
                        push.startStop.stop r
                    , stopE <#> (_ *> (ccb (pure unit) *> push.startStop.start unit))
                    ]
                ]
                [ text $ oneOf
                    [ startE $> "Turn on"
                    , stopE $> "Turn off"
                    ]
                ]
            , D.div
                [oneOfMap (map (attr D.Style))
                    [ stopE $> "display:block;"
                    , startE $> "display:none;"
                    ]
                ]
                ( map
                    ( \e -> D.input
                        [oneOf
                            [ pure (D.Xtype := "checkbox")
                            , pure (D.OnClick := cb (const (e unit)))
                            , startE $> (D.Checked := "false")
                            ]
                        ]
                        []
                    )
                    ([ _.cbx0, _.cbx1, _.cbx2, _.cbx3 ] <@> push.cbx)
                )
            ]
      )
  }