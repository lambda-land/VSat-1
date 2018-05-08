module Main where

import Criterion.Main as C

import Run
import Criterion.Types
import Data.Csv
import Text.Printf
import Data.Text (Text,pack)
import qualified Data.Vector as V
import Prelude hiding (writeFile, appendFile)
import GHC.Generics (Generic)
import qualified Data.ByteString.Char8 as BS (pack)
import Data.ByteString.Lazy (writeFile, appendFile)
import VProp ( VProp
             , Readable
             , readStr
             , vPropNoShare
             , mkLargeVProp
             , numTerms
             , numChc
             , numPlain
             , numSharedDims
             , numSharedPlain
             , maxShared
             )
import Test.QuickCheck (generate, arbitrary)

import System.CPUTime
-- import
-- import Data.Time.Clock
-- import Data.Time.Calendar

myConfig :: Config
myConfig = C.defaultConfig { resamples = 2 }

-- | Required field namings for cassava csv library
data RunData = RunData { shared_         :: !Text
                       , runNum_          :: !Integer
                       , scale_          :: !Integer
                       , numTerms_       :: !Integer
                       , numChc_         :: !Integer
                       , numPlain_       :: !Integer
                       , numSharedDims_  :: !Integer
                       , numSharedPlain_ :: !Integer
                       , maxShared_      :: !Integer
                       } deriving (Generic, Show)

data TimeData = TimeData { name__   :: !Text
                         , runNum__ :: !Integer
                         , scale__  :: !Integer
                         , time__   :: !Double
                         } deriving (Generic,Show)

instance ToNamedRecord RunData
instance ToNamedRecord TimeData

-- run with $ stack bench --benchmark-arguments "--output results.html --csv timing_results.csv"
descFile :: FilePath
descFile = "desc_results.csv"

timingFile :: FilePath
timingFile = "timing_results.csv"

eraseFile :: FilePath -> IO ()
eraseFile = flip writeFile ""

main :: IO ()
main = do
  mapM_ eraseFile [descFile, timingFile]
  mapM_ benchAndInc $ zip [1..] $ [100,200..3000] >>= replicate 2

-- | The run number, used to join descriptor and timing data later
type RunNum = Integer

-- | The Term size used to generate an arbitrary VProp of size TermSize
type TermSize = Integer

type RunMetric = (RunNum, TermSize)

-- benchAll :: (RunNum, Integer) -> IO ()
-- benchAll (rn, n) = do
--   noShProp <- fmap readStr <$>
--               (generate $ mkLargeVProp (fromInteger n) vPropNoShare :: IO (VProp Readable))
--   prop <- fmap readStr <$>
--           (generate $ mkLargeVProp (fromInteger n) arbitrary :: IO (VProp Readable))
--   let descriptorsFs = [ numTerms
--                       , numChc
--                       , numPlain
--                       , numSharedDims
--                       , numSharedPlain
--                       , maxShared
--                       ]

--   -- there must be a better way
--       [s,c,p,sd,sp,ms] = descriptorsFs <*> pure noShProp
--       [s2,c2,p2,sd2,sp2,ms2] = descriptorsFs <*> pure prop

--       noShPropRecord = RunData "Unique" rn n s  c  p  sd  sp  ms
--       propRecord =     RunData "Shared" rn n s2 c2 p2 sd2 sp2 ms2

--       headers :: Header
--       headers = V.fromList $ BS.pack <$>
--                 [ "shared_"
--                 , "runNum_"
--                 , "scale_"
--                 , "numTerms_"
--                 , "numChc_"
--                 , "numPlain_"
--                 , "numSharedDims_"
--                 , "numSharedPlain_"
--                 , "maxShared_"
--                 ]

--   -- write out to descriptor csv file
--   appendFile descFile $ encodeByName headers $ pure noShPropRecord
--   appendFile descFile $ encodeByName headers $ pure propRecord

--   C.defaultMainWith myConfig
--     [ C.bgroup ("Unique/" ++ show rn ++ "/" ++ show n)
--       [ bench "Brute Force" $ C.nfIO (runEnv True False False [] noShProp)
--       , bench "And Decomposition" $ C.nfIO (runEnv True True False [] noShProp)
--       , bench "Variational Solve" $ C.nfIO (runEnv False False False [] noShProp)
--       ]
--     , C.bgroup ("Shared/" ++ show rn ++ "/" ++ show n)
--       [ bench "Brute Force" $ C.nfIO (runEnv True False False [] prop)
--       , bench "And Decomposition" $ C.nfIO (runEnv True True False [] prop)
--       , bench "Variational Solve" $ C.nfIO (runEnv False False False [] prop)
--       ]
--     ]

-- | Give a descriptor, run metrics, and a prop, generate the descriptor metrics
-- for the prop and write them out to a csv
writeDesc :: String -> RunMetric -> VProp Readable -> IO ()
writeDesc desc (rn, n) prop' = do
  let descriptorsFs = [ numTerms
                      , numChc
                      , numPlain
                      , numSharedDims
                      , numSharedPlain
                      , maxShared
                      ]
      prop = toReadable prop'
      [s,c,p,sd,sp,ms] = descriptorsFs <*> pure prop
      row = RunData (pack desc) rn n s c p sd sp ms

  appendFile descFile $ encodeByName headers $ pure row

  where
    headers = V.fromList $ BS.pack <$>
              [ "shared_"
              , "runNum_"
              , "scale_"
              , "numTerms_"
              , "numChc_"
              , "numPlain_"
              , "numSharedDims_"
              , "numSharedPlain_"
              , "maxShared_"
              ]

writeTime :: Text -> RunMetric -> Double -> IO ()
writeTime str (rn, n) time_ = appendFile timingFile $ encodeByName headers $ pure row
  where row = TimeData str rn n time_
        headers = V.fromList $ BS.pack <$> ["name__", "runNum__", "scale__", "time__"]

-- | Unbox the readable type to the underlying string value
toReadable :: VProp Readable -> VProp String
toReadable = fmap readStr

-- | Bench only and decomposition and Incremental Solve given run metrics to
-- generate the prop with and log the run
benchAndInc :: RunMetric -> IO ()
benchAndInc metrics@(rn, n) = do
  noShProp <- generate $ mkLargeVProp (fromInteger n) vPropNoShare :: IO (VProp Readable)
  prop <- generate $ mkLargeVProp (fromInteger n) arbitrary :: IO (VProp Readable)
  writeDesc "Unique" metrics noShProp
  writeDesc "Shared" metrics prop

  -- | run incremental solve
  (tm1, _) <- time $! runEnv False False False [] (toReadable noShProp)
  (tm2, _) <- time $! runEnv False False False [] (toReadable prop)

  -- | run and decomp
  (tm3, _) <- time $! runEnv True True False [] (toReadable noShProp)
  (tm4, _) <- time $! runEnv True True False [] (toReadable prop)

  -- | log the times
  writeTime "Unique/VSolve" metrics tm1
  writeTime "Shared/VSolve" metrics tm2
  writeTime "Unique/AndDecomp" metrics tm3
  writeTime "Shared/AndDecomp" metrics tm4

  print $ "Run: " ++ show rn ++ " Scale: " ++ show n ++ " | " ++ " Times: " ++
    "VSolve: " ++ show tm1 ++ " | " ++ show tm2 ++ " | " ++ "AndDecomp: " ++ show tm3 ++ " | " ++ show tm4

  -- C.defaultMainWith myConfig
  --   [ C.bgroup ("Unique/" ++ show rn ++ "/" ++ show n)
  --     [ bench "Variational Solve" $ C.nfIO (runEnv False False False [] noShProp)
  --     , bench "And Decomposition" $ C.nfIO (runEnv True True False [] noShProp)
  --     ]
  --   , C.bgroup ("Shared/" ++ show rn ++ "/" ++ show n)
  --     [ bench "Variational Solve" $ C.nfIO (runEnv False False False [] prop)
  --     , bench "And Decomposition" $ C.nfIO (runEnv True True False [] prop)
  --     ]
  --   ]

time :: IO t -> IO (Double, t)
time a = do
  start <- getCPUTime
  v <- a
  end <- getCPUTime
  let diff = (fromIntegral (end - start)) / (10 ^ 12)
  -- printf "Computation time: %0.3f sec\n" (diff :: Double)
  return (diff, v)
