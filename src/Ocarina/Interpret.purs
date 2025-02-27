module Ocarina.Interpret where

import Prelude

import Control.Bind (bindFlipped)
import Control.Monad.ST.Global as Region
import Control.Monad.ST.Internal as Ref
import Control.Promise (Promise, toAff, toAffE)
import Data.ArrayBuffer.Types (ArrayBuffer, Float32Array, Uint8Array)
import Data.Maybe (Maybe(..), maybe)
import Data.Symbol (class IsSymbol)
import Data.Typelevel.Num (class Lt, class Nat, class Pos, D1)
import Data.Vec (Vec)
import Data.Vec as V
import Effect (Effect)
import Effect.Aff (Aff, bracket)
import Effect.Class (class MonadEffect, liftEffect)
import Ocarina.Control (class ValidateOutputChannelCount)
import Ocarina.Core as C
import Ocarina.WebAPI (AudioContext, BrowserAudioBuffer)
import Ocarina.WebAPI as WebAPI
import Random.LCG (mkSeed)
import Simple.JSON as JSON
import Test.QuickCheck (arbitrary)
import Test.QuickCheck.Gen (Gen, evalGen)
import Type.Row.Homogeneous (class Homogeneous)
import Unsafe.Coerce (unsafeCoerce)
import Web.File.Blob (Blob)
import Web.File.Url (createObjectURL)

-- foreign non-interpret
data AudioWorkletNodeRequest
  (node :: Symbol)
  (numberOfInputs :: Type)
  (numberOfOutputs :: Type)
  (outputChannelCount :: Type)
  (parameterData :: Row Type)
  (processorOptions :: Row Type) = AudioWorkletNodeRequest

data AudioWorkletNodeResponse
  (node :: Symbol)
  (numberOfInputs :: Type)
  (numberOfOutputs :: Type)
  (outputChannelCount :: Type)
  (parameterData :: Row Type)
  (processorOptions :: Row Type)

foreign import bufferSampleRate :: BrowserAudioBuffer -> Number
foreign import bufferLength :: BrowserAudioBuffer -> Int
foreign import bufferDuration :: BrowserAudioBuffer -> Number
foreign import bufferNumberOfChannels :: BrowserAudioBuffer -> Int
foreign import getFFTSize :: WebAPI.AnalyserNode -> Effect Int

foreign import setFFTSize :: WebAPI.AnalyserNode -> Int -> Effect Unit

foreign import getFrequencyBinCount :: WebAPI.AnalyserNode -> Effect Int

foreign import getSmoothingTimeConstant :: WebAPI.AnalyserNode -> Effect Number

foreign import setSmoothingTimeConstant
  :: WebAPI.AnalyserNode -> Number -> Effect Unit

foreign import getMinDecibels :: WebAPI.AnalyserNode -> Effect Number

foreign import setMinDecibels :: WebAPI.AnalyserNode -> Number -> Effect Unit

foreign import getMaxDecibels :: WebAPI.AnalyserNode -> Effect Number

foreign import setMaxDecibels :: WebAPI.AnalyserNode -> Number -> Effect Unit

foreign import getFloatTimeDomainData
  :: WebAPI.AnalyserNode -> Effect Float32Array

foreign import getFloatFrequencyData
  :: WebAPI.AnalyserNode -> Effect Float32Array

foreign import getByteTimeDomainData :: WebAPI.AnalyserNode -> Effect Uint8Array

foreign import getByteFrequencyData :: WebAPI.AnalyserNode -> Effect Uint8Array

-- | For a given audio context, add the audio worklet module at a given URI.
foreign import audioWorkletAddModule_
  :: WebAPI.AudioContext -> String -> Effect (Promise Unit)

-- | Gets the audio ctime from an audio context.
foreign import getAudioClockTime :: WebAPI.AudioContext -> Effect Number

-- | Stops a media recorder
foreign import stopMediaRecorder :: WebAPI.MediaRecorder -> Effect Unit

-- | For a given MIME type, pass the URL-ified content of a media recorder as a string to a handler.
-- |
-- | ```purescript
-- | mediaRecorderToUrl "audio/ogg" setAudioTagUrlToThisContent recorder
-- | ```
foreign import mediaRecorderToBlob
  :: String -> (Blob -> Effect Unit) -> WebAPI.MediaRecorder -> Effect Unit

mediaRecorderToUrl
  :: String -> (String -> Effect Unit) -> WebAPI.MediaRecorder -> Effect Unit
mediaRecorderToUrl s cb mr = flip (mediaRecorderToBlob s) mr
  (bindFlipped cb <<< createObjectURL)

-- | Is this MIME type supported by this browser.
foreign import isTypeSupported :: String -> Effect Boolean

-- | Given an audio context and a URI, decode the content of the URI to an audio buffer.
decodeAudioDataFromUri
  :: WebAPI.AudioContext -> String -> Aff WebAPI.BrowserAudioBuffer
decodeAudioDataFromUri ctx s =
  toAffE (fetchArrayBuffer s) >>=
    (toAffE <<< decodeAudioDataFromArrayBuffer ctx)

bracketCtx :: forall a. (AudioContext -> Aff a) -> Aff a
bracketCtx = bracket (liftEffect context) (liftEffect <<< close)

foreign import fetchArrayBuffer :: String -> Effect (Promise ArrayBuffer)

foreign import decodeAudioDataFromArrayBuffer
  :: WebAPI.AudioContext
  -> ArrayBuffer
  -> Effect (Promise WebAPI.BrowserAudioBuffer)

-- | Given an audio context and a base-64-encoded audio file, decode the content of the string to an audio buffer.
foreign import decodeAudioDataFromBase64EncodedString
  :: WebAPI.AudioContext -> String -> Effect (Promise WebAPI.BrowserAudioBuffer)

foreign import makePeriodicWaveImpl
  :: WebAPI.AudioContext
  -> Array Number
  -> Array Number
  -> Effect WebAPI.BrowserPeriodicWave

-- | For a given audio context, use an audio buffer to create a browser audio buffer. This is useful when doing DSP in the browser.  Note that `AudioBuffer` is a purescript type whereas `WebAPI.BrowserAudioBuffer` is an optimized browser-based type. That means that, once you write to `WebAPI.BrowserAudioBuffer`, it is effectively a blob and its contents cannot be retrieved using the Ocarina API.
foreign import makeAudioBuffer_ :: WebAPI.AudioContext -> { size :: Int, arr :: Array (Array Number) } -> Effect WebAPI.BrowserAudioBuffer

makeAudioBuffer :: WebAPI.AudioContext -> AudioBuffer -> Effect WebAPI.BrowserAudioBuffer
makeAudioBuffer ctx (AudioBuffer size arr) = makeAudioBuffer_ ctx { size, arr }

-- | Make a float 32 array. Useful when creating a waveshaper node.
foreign import makeFloatArray :: Array Number -> WebAPI.BrowserFloatArray

-- | Make a new audio context.
foreign import context_ :: Effect WebAPI.AudioContext

context :: forall m. MonadEffect m => m WebAPI.AudioContext
context = liftEffect context_

-- | Send 0s from a context immediately. This is useful on iOS so that the context doesn't switch to a suspended state.
foreign import constant0Hack_ :: WebAPI.AudioContext -> Effect (Effect Unit)

constant0Hack :: forall e. MonadEffect e => WebAPI.AudioContext -> e (Effect Unit)
constant0Hack = liftEffect <<< constant0Hack_

-- | Get the state of the context
foreign import contextState_ :: WebAPI.AudioContext -> Effect String

contextState :: forall e. MonadEffect e => WebAPI.AudioContext -> e String
contextState = liftEffect <<< contextState_

-- | Get the state of the context

-- | Get the state of the context
foreign import contextResume_ :: WebAPI.AudioContext -> Effect (Promise Unit)

contextResume :: forall e. MonadEffect e => WebAPI.AudioContext -> e (Promise Unit)
contextResume = liftEffect <<< contextResume_

contextResumeAff :: forall e. MonadEffect e => WebAPI.AudioContext -> e (Aff Unit)
contextResumeAff = (map <<< map) toAff contextResume

-- | Close an audio context.
foreign import close_ :: WebAPI.AudioContext -> Effect Unit

close :: forall e. MonadEffect e => WebAPI.AudioContext -> e Unit
close ctx = liftEffect do
  st <- contextState ctx
  when (st /= "closed") (close_ ctx)

foreign import data BrowserMediaStream :: Type

foreign import getBrowserMediaStreamImpl
  :: Boolean -> Boolean -> Effect (Promise BrowserMediaStream)

data Audio

audioWorkletAddModule
  :: forall node payload numberOfInputs numberOfOutputs outputChannelCount parameterData
       processorOptions
   . IsSymbol node
  => Nat numberOfInputs
  => Pos numberOfOutputs
  => ValidateOutputChannelCount numberOfOutputs outputChannelCount
  => Homogeneous parameterData (C.AudioParameter payload)
  => JSON.WriteForeign { | processorOptions }
  => WebAPI.AudioContext
  -> String
  -> ( AudioWorkletNodeRequest node numberOfInputs
         numberOfOutputs
         outputChannelCount
         parameterData
         processorOptions

     )
  -> Aff
       ( AudioWorkletNodeResponse node numberOfInputs
           numberOfOutputs
           outputChannelCount
           parameterData
           processorOptions

       )
audioWorkletAddModule c px _ = toAffE (audioWorkletAddModule_ c px) $>
  unsafeCoerce unit

browserMediaStreamToBrowserMicrophone
  :: BrowserMediaStream -> WebAPI.BrowserMicrophone
browserMediaStreamToBrowserMicrophone = unsafeCoerce

browserMediaStreamToBrowserCamera :: BrowserMediaStream -> WebAPI.BrowserCamera
browserMediaStreamToBrowserCamera = unsafeCoerce

getMicrophoneAndCamera
  :: Boolean
  -> Boolean
  -> Aff
       { microphone :: Maybe WebAPI.BrowserMicrophone
       , camera :: Maybe WebAPI.BrowserCamera
       }
getMicrophoneAndCamera audio video =
  ( \i ->
      { microphone:
          if audio then pure $ browserMediaStreamToBrowserMicrophone i
          else Nothing
      , camera:
          if video then pure $ browserMediaStreamToBrowserCamera i else Nothing
      }
  )
    <$> toAffE (getBrowserMediaStreamImpl audio video)

-- | Create a unit cache. This returns a fresh empty object `{}` that is used to cache audio units.
foreign import makeFFIAudioSnapshot
  :: WebAPI.AudioContext -> Effect FFIAudioSnapshot

foreign import contextFromSnapshot :: FFIAudioSnapshot -> WebAPI.AudioContext
foreign import advanceWriteHead :: FFIAudioSnapshot -> Number -> Effect Unit

-- | Make a browser periodic wave. A PureScript-ified version of the periodic wave constructor
-- | from the [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/PeriodicWave/PeriodicWave).
-- | Given an audio context, a vector of real parts of complex numbers, and a vector of imaginary parts of complex numbers, build a periodic wave interpretable by the Web Audio API.
makePeriodicWave
  :: forall len
   . Lt D1 len
  => WebAPI.AudioContext
  -> Vec len Number
  -> Vec len Number
  -> Effect WebAPI.BrowserPeriodicWave
makePeriodicWave ctx a b = makePeriodicWaveImpl ctx (V.toArray a) (V.toArray b)

-- | A multi-channel audio buffer.
data AudioBuffer = AudioBuffer Int (Array (Array Number))

instance showAudioBuffer :: Show AudioBuffer where
  show (AudioBuffer i a) = "AudioBuffer <" <> show i <> " : " <> show a <> ">"

derive instance eqAudioBuffer :: Eq AudioBuffer

-- | Make a multi-channel audio buffer. Each vector into the multi-channel buffer must be the same length.
audioBuffer
  :: forall bch blen
   . Pos bch
  => Pos blen
  => Int
  -> Vec bch (Vec blen Number)
  -> AudioBuffer
audioBuffer i v = AudioBuffer i (map V.toArray $ V.toArray v)

-- foreign
data FFIAudioSnapshot

type Mbe = forall a b. b -> (a -> b) -> Maybe a -> b

foreign import deleteFromCache_
  :: C.DeleteFromCache -> FFIAudioSnapshot -> Effect Unit

foreign import disconnectXFromY_
  :: C.DisconnectXFromY -> FFIAudioSnapshot -> Effect Unit

foreign import connectXToY_ :: C.ConnectXToY -> FFIAudioSnapshot -> Effect Unit
foreign import makeAllpass_ :: Mbe -> C.MakeAllpass -> FFIAudioSnapshot -> Effect Unit
foreign import makeAnalyser_
  :: Mbe -> C.MakeAnalyser -> FFIAudioSnapshot -> Effect Unit

foreign import makeAudioWorkletNode_
  :: Mbe -> C.MakeAudioWorkletNode -> FFIAudioSnapshot -> Effect Unit

foreign import makeBandpass_
  :: Mbe -> C.MakeBandpass -> FFIAudioSnapshot -> Effect Unit

foreign import makeConstant_
  :: Mbe -> C.MakeConstant -> FFIAudioSnapshot -> Effect Unit

foreign import makeConvolver_
  :: Mbe -> C.MakeConvolver -> FFIAudioSnapshot -> Effect Unit

foreign import makeDelay_ :: Mbe -> C.MakeDelay -> FFIAudioSnapshot -> Effect Unit
foreign import makeDynamicsCompressor_
  :: Mbe -> C.MakeDynamicsCompressor -> FFIAudioSnapshot -> Effect Unit

foreign import makeGain_ :: Mbe -> C.MakeGain -> FFIAudioSnapshot -> Effect Unit
foreign import makeHighpass_
  :: Mbe -> C.MakeHighpass -> FFIAudioSnapshot -> Effect Unit

foreign import makeHighshelf_
  :: Mbe -> C.MakeHighshelf -> FFIAudioSnapshot -> Effect Unit

foreign import makeIIRFilter_
  :: Mbe -> C.MakeIIRFilter -> FFIAudioSnapshot -> Effect Unit

foreign import makeLoopBuf_ :: Mbe -> C.MakeLoopBuf -> FFIAudioSnapshot -> Effect Unit
foreign import makeLowpass_ :: Mbe -> C.MakeLowpass -> FFIAudioSnapshot -> Effect Unit
foreign import makeLowshelf_
  :: Mbe -> C.MakeLowshelf -> FFIAudioSnapshot -> Effect Unit

foreign import makeMediaElement_
  :: Mbe -> C.MakeMediaElement -> FFIAudioSnapshot -> Effect Unit

foreign import makeMicrophone_
  :: Mbe -> C.MakeMicrophone -> FFIAudioSnapshot -> Effect Unit

foreign import makeNotch_ :: Mbe -> C.MakeNotch -> FFIAudioSnapshot -> Effect Unit
foreign import makePeaking_ :: Mbe -> C.MakePeaking -> FFIAudioSnapshot -> Effect Unit
foreign import makePeriodicOsc_
  :: Mbe -> C.MakePeriodicOsc -> FFIAudioSnapshot -> Effect Unit

foreign import makePlayBuf_ :: Mbe -> C.MakePlayBuf -> FFIAudioSnapshot -> Effect Unit
foreign import makeRecorder_
  :: Mbe -> C.MakeRecorder -> FFIAudioSnapshot -> Effect Unit

foreign import makeSawtoothOsc_
  :: Mbe -> C.MakeSawtoothOsc -> FFIAudioSnapshot -> Effect Unit

foreign import makeSinOsc_ :: Mbe -> C.MakeSinOsc -> FFIAudioSnapshot -> Effect Unit
foreign import makeSpeaker_ :: C.MakeSpeaker -> FFIAudioSnapshot -> Effect Unit
foreign import makeSquareOsc_
  :: Mbe -> C.MakeSquareOsc -> FFIAudioSnapshot -> Effect Unit

foreign import makeStereoPanner_
  :: Mbe -> C.MakeStereoPanner -> FFIAudioSnapshot -> Effect Unit

foreign import makeTriangleOsc_
  :: Mbe -> C.MakeTriangleOsc -> FFIAudioSnapshot -> Effect Unit

foreign import makeWaveShaper_
  :: Mbe -> C.MakeWaveShaper -> FFIAudioSnapshot -> Effect Unit

foreign import setAnalyserNodeCb_
  :: C.SetAnalyserNodeCb -> FFIAudioSnapshot -> Effect Unit

foreign import setMediaRecorderCb_
  :: C.SetMediaRecorderCb -> FFIAudioSnapshot -> Effect Unit

foreign import setWaveShaperCurve_
  :: C.SetWaveShaperCurve -> FFIAudioSnapshot -> Effect Unit

foreign import setAudioWorkletParameter_
  :: C.SetAudioWorkletParameter -> FFIAudioSnapshot -> Effect Unit

foreign import setBuffer_ :: C.SetBuffer -> FFIAudioSnapshot -> Effect Unit
foreign import setConvolverBuffer_
  :: C.SetConvolverBuffer -> FFIAudioSnapshot -> Effect Unit

foreign import setPeriodicOsc_
  :: C.SetPeriodicOsc -> FFIAudioSnapshot -> Effect Unit

foreign import setOnOff_ :: C.SetOnOff -> FFIAudioSnapshot -> Effect Unit
foreign import setDuration_
  :: Mbe -> C.SetDuration -> FFIAudioSnapshot -> Effect Unit

foreign import setBufferOffset_
  :: C.SetBufferOffset -> FFIAudioSnapshot -> Effect Unit

foreign import setLoopStart_
  :: C.SetLoopStart -> FFIAudioSnapshot -> Effect Unit

foreign import setLoopEnd_ :: C.SetLoopEnd -> FFIAudioSnapshot -> Effect Unit
foreign import setRatio_ :: C.SetRatio -> FFIAudioSnapshot -> Effect Unit
foreign import setOffset_ :: C.SetOffset -> FFIAudioSnapshot -> Effect Unit
foreign import setGain_ :: C.SetGain -> FFIAudioSnapshot -> Effect Unit
foreign import setQ_ :: C.SetQ -> FFIAudioSnapshot -> Effect Unit
foreign import setFrequency_
  :: C.SetFrequency -> FFIAudioSnapshot -> Effect Unit

foreign import setKnee_ :: C.SetKnee -> FFIAudioSnapshot -> Effect Unit
foreign import setAttack_ :: C.SetAttack -> FFIAudioSnapshot -> Effect Unit
foreign import setRelease_ :: C.SetRelease -> FFIAudioSnapshot -> Effect Unit
foreign import setPan_ :: C.SetPan -> FFIAudioSnapshot -> Effect Unit
foreign import setThreshold_
  :: C.SetThreshold -> FFIAudioSnapshot -> Effect Unit

foreign import setDelay_ :: C.SetDelay -> FFIAudioSnapshot -> Effect Unit
foreign import setPlaybackRate_
  :: C.SetPlaybackRate -> FFIAudioSnapshot -> Effect Unit

effectfulAudioInterpret
  :: Ref.STRef Region.Global Int -> C.AudioInterpret (FFIAudioSnapshot -> Effect Unit)
effectfulAudioInterpret seed = C.AudioInterpret
  { ids: do
      s <- Ref.read seed
      let
        o = show
          (evalGen (arbitrary :: Gen Int) { newSeed: mkSeed s, size: 5 })
      void $ Ref.modify (add 1) seed
      pure o
  , deleteFromCache: deleteFromCache_
  , disconnectXFromY: disconnectXFromY_
  , connectXToY: connectXToY_
  , makeAllpass: makeAllpass_ maybe
  , makeAnalyser: makeAnalyser_ maybe
  , makeAudioWorkletNode: makeAudioWorkletNode_ maybe
  , makeBandpass: makeBandpass_ maybe
  , makeConstant: makeConstant_ maybe
  , makeConvolver: makeConvolver_ maybe
  , makeDelay: makeDelay_ maybe
  , makeDynamicsCompressor: makeDynamicsCompressor_ maybe
  , makeGain: makeGain_ maybe
  , makeHighpass: makeHighpass_ maybe
  , makeHighshelf: makeHighshelf_ maybe
  , makeIIRFilter: makeIIRFilter_ maybe
  , makeLoopBuf: makeLoopBuf_ maybe
  , makeLowpass: makeLowpass_ maybe
  , makeLowshelf: makeLowshelf_ maybe
  , makeMediaElement: makeMediaElement_ maybe
  , makeMicrophone: makeMicrophone_ maybe
  , makeNotch: makeNotch_ maybe
  , makePeaking: makePeaking_ maybe
  , makePeriodicOsc: makePeriodicOsc_ maybe
  , makePlayBuf: makePlayBuf_ maybe
  , makeRecorder: makeRecorder_ maybe
  , makeSawtoothOsc: makeSawtoothOsc_ maybe
  , makeSinOsc: makeSinOsc_ maybe
  , makeSpeaker: makeSpeaker_
  , makeSquareOsc: makeSquareOsc_ maybe
  , makeStereoPanner: makeStereoPanner_ maybe
  , makeTriangleOsc: makeTriangleOsc_ maybe
  , makeWaveShaper: makeWaveShaper_ maybe
  , setAnalyserNodeCb: setAnalyserNodeCb_
  , setMediaRecorderCb: setMediaRecorderCb_
  , setWaveShaperCurve: setWaveShaperCurve_
  , setAudioWorkletParameter: setAudioWorkletParameter_
  , setBuffer: setBuffer_
  , setConvolverBuffer: setConvolverBuffer_
  , setDuration: setDuration_ maybe
  , setPeriodicOsc: setPeriodicOsc_
  , setOnOff: setOnOff_
  , setBufferOffset: setBufferOffset_
  , setLoopStart: setLoopStart_
  , setLoopEnd: setLoopEnd_
  , setRatio: setRatio_
  , setOffset: setOffset_
  , setAttack: setAttack_
  , setGain: setGain_
  , setQ: setQ_
  , setPan: setPan_
  , setThreshold: setThreshold_
  , setRelease: setRelease_
  , setKnee: setKnee_
  , setDelay: setDelay_
  , setPlaybackRate: setPlaybackRate_
  , setFrequency: setFrequency_
  }
