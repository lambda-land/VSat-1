import           Control.Arrow           (first, second)
import           Criterion.Main
import           Criterion.Main.Options
import           Criterion.Types         (Config (..))
import           Data.Aeson              (decodeStrict)
import           Control.Monad           (replicateM, foldM, liftM2)
import           Data.Bifunctor          (bimap)
import           Data.Bitraversable      (bimapM)
import qualified Data.ByteString         as BS (readFile)
import           Data.Either             (lefts, rights)
import           Data.Foldable           (foldr')
import           Data.List               (sort,delete,intersperse)
import           Data.Map                (size, Map, (!))
import qualified Data.SBV                as S
import qualified Data.SBV.Control        as SC
import qualified Data.SBV.Internals      as SI
import           Data.Text               (pack, unpack,Text)
import qualified Data.Text.IO            as T (writeFile)
import           System.IO
import           Text.Megaparsec         (parse)

import           Api
import           CaseStudy.Auto.Auto
import           CaseStudy.Auto.Lang
import           CaseStudy.Auto.Parser   (langParser)
import           CaseStudy.Auto.Run
import           CaseStudy.Auto.CompactEncode
import           Config
import           Opts
import           Run                     (runAD, runBF)
import           Result
import           Utils
import           VProp.Core
import           VProp.SBV               (toPredicate)
import           VProp.Types

-- | a large dataset of queries
-- autoFile :: FilePath
-- autoFile = "bench/AutoBench/Automotive02_merged_evolution_history_integer.json"

autoFileBool :: FilePath
autoFileBool = "bench/AutoBench/Automotive02_merged_evolution_history_boolean.json"

-- | a different file that represents a possible json
smAutoFile :: FilePath
smAutoFile = "bench/AutoBench/vsat_small_example.json"

-- | a chunk of the large autoFile above
chAutoFile :: FilePath
chAutoFile = "bench/AutoBench/vsat_small_chunk.json"

-- main :: IO (V String (Maybe ThmResult))

sliceAndNegate n xs = fromList' (&&&) $ bnot <$> drop n xs

ds :: [VProp Text String String]
ds = bRef <$> ["D_0","D_2","D_4","D_5"]
-- D_0 /\    D_2   /\     D_4   /\  D_5
-- <0 /\ <=0 /\ <1 /\ <=1 /\ <2 /\ <= 2

[d0, d2, d4, d5] = ds

-- dimConf' :: VProp Text String String
-- encoding for 6 configs that make sure the inequalities encompass each other
sumConf = (d0 &&& fromList' (&&&) (bnot <$> tail ds)) -- <0
          ||| ((bnot d0) &&& d2 &&& (bnot d4 &&& bnot d5))   -- <0 /\ <1
          ||| ((bnot d0)&&& (bnot d2) &&& d4 &&& bnot d5) -- <0 /\ <1 /\
          ||| ((bnot d0)&&& (bnot d2) &&& (bnot d4) &&& d5) -- <0 /\ <1 /\

-- | Configs that select only one version
d0Conf = (d0 &&& fromList' (&&&) (bnot <$> tail ds)) -- <0
d2Conf = ((bnot d0) &&& d2 &&& (bnot d4 &&& bnot d5))   -- <0 /\ <1
d3Conf = ((bnot d0) &&& (bnot d2) &&& d4 &&& bnot d5) -- <0 /\ <1 /\
d4Conf = ((bnot d0) &&& (bnot d2) &&& (bnot d4) &&& d5) -- <0 /\ <1 /\
dAllConf = (d0 &&& d2 &&& d4 &&& d5) -- <0 /\ <1 /\

-- | Configs that remove choices and leave that particular choice
justV1Conf = (bnot d2) &&& (bnot d4) &&& (bnot d5)
justV2Conf = (bnot d0) &&& (bnot d4) &&& (bnot d5)
justV3Conf = (bnot d0) &&& (bnot d2) &&& (bnot d5)
justV4Conf = (bnot d0) &&& (bnot d2) &&& (bnot d4)

justV12Conf = (bnot d4) &&& (bnot d5)
justV123Conf = (bnot d5)

negConf = conjoin $ bnot <$> ds

baselineSolve :: [AutoLang Text Text] -> IO S.SatResult
baselineSolve props = S.runSMT $
  do assocMap <- makeAssocMap props
     SC.query $
       do
         (assocMap ! plainHandle) >>= S.constrain
         fmap S.SatResult SC.getSMTResult

-- run with stack bench --profile vsat:auto --benchmark-arguments='+RTS -S -RTS --output timings.html'
main = do
  -- readfile is strict
  bJsn <- BS.readFile autoFileBool
  let (Just bAuto) = decodeStrict bJsn :: Maybe Auto
      !bCs = constraints bAuto
      bPs' = parse langParser "" <$> bCs
      bPs = fmap (simplifyCtxs . renameCtxs sameCtxs) $ rights bPs'

      -- | Hardcoding equivalencies in generated dimensions to reduce number of
      -- dimensions to 4
      sameDims :: Text -> Text
      sameDims d
        | d == "D_1" = "D_2"
        | d == "D_3" = "D_4"
        | otherwise = d

      !bProp = ((renameDims sameDims) . naiveEncode . autoToVSat) $ autoAndJoin (bPs)
      !bPropOpts = applyOpts defConf bProp
      toAutoConf = Just . toDimProp
      autoNegConf = (Just $ toDimProp negConf)

      run !desc !f prop = bench desc $! nfIO (f prop)

      mkBench alg conf !f prop = run desc f prop
        where
          !desc' = ["Chc",show nChc , "numPlain", show nPln , "Compression", show ratio]
          !desc = mconcat $ intersperse "/" $ pure alg ++ pure conf ++ desc'
          !nPln = numPlain prop
          !nChc = numChc prop
          ratio :: Double
          !ratio = fromRational $ compressionRatio prop

  -- Convert the fmf's to actual configurations
  [ppV1]   <- genConfigPool d0Conf
  [ppV2]   <- genConfigPool d2Conf
  [ppV3]   <- genConfigPool d3Conf
  [ppV4]   <- genConfigPool d4Conf
  [ppVAll] <- genConfigPool dAllConf

  [justV1] <- genConfigPool justV1Conf
  [justV2] <- genConfigPool justV2Conf
  [justV3] <- genConfigPool justV3Conf
  [justV4] <- genConfigPool justV4Conf

  [justV12] <- genConfigPool justV12Conf
  [justV123] <- genConfigPool justV123Conf

  let !bPropV1   = selectVariantTotal ppV1 bProp
      !bPropV2   = selectVariantTotal ppV2 bProp
      !bPropV3   = selectVariantTotal ppV3 bProp
      !bPropV4   = selectVariantTotal ppV4 bProp
      !bPropVAll = selectVariantTotal ppVAll bProp

      (Just bPropJustV1) = selectVariant justV1 bProp
      (Just bPropJustV2) = selectVariant justV2 bProp
      (Just bPropJustV3) = selectVariant justV3 bProp
      (Just bPropJustV4) = selectVariant justV4 bProp
      (Just bPropJustV12) = selectVariant justV12 bProp
      (Just bPropJustV123) = selectVariant justV123 bProp

  -- res' <- runIncrementalSolve bPs

  -- mdl <- baselineSolve bPs
  -- print mdl
  -- putStrLn $ "Done with parse: "
  -- mapM_ (putStrLn . show) $ (sPs)
  -- putStrLn $! show bProp
  -- putStrLn $ "------------------"
  -- putStrLn $ "Solving: "
  -- res' <- satWithConf (toAutoConf d0Conf) emptyConf bProp
  -- res' <- ad id bProp
  -- res' <- bfWithConf (toAutoConf d0Conf) emptyConf bProp
  -- res' <- satWith emptyConf sProp
  -- putStrLn "DONE!"
  -- print $ (length $ show res')
  -- print "done"
  -- let !p = prop 6000
  -- print $ length p
  -- -- res <- test 10
  -- res <- S.runSMT $ do p' <- mapM S.sBool p
  --                      SC.query $! test' p'
  -- putStrLn "Running Good:\n"
  -- goodRes <- testS goodS 1000

  defaultMain
    [
    bgroup "Auto" [
        -- v - v
                     mkBench "v-->v" "V1"  (satWithConf (toAutoConf d0Conf) emptyConf) bProp
                   , mkBench "v-->v" "V2"  (satWithConf (toAutoConf d2Conf) emptyConf) bProp
                   , mkBench "v-->v" "V3"  (satWithConf (toAutoConf d3Conf) emptyConf) bProp
                   , mkBench "v-->v" "V4"  (satWithConf (toAutoConf d4Conf) emptyConf) bProp
                   , mkBench "v-->v" "EvolutionAware" (satWithConf (toAutoConf sumConf) emptyConf) bProp
                   , mkBench "v-->v" "V1*V2"        (satWith emptyConf) bPropJustV12
                   , mkBench "v-->v" "V1*V2*V3"     (satWith emptyConf) bPropJustV123
                   , mkBench "v-->v" "V1*V2*V3*V4"  (satWith emptyConf) bProp

                   -- p - v
                   , mkBench "p-->v" "V1"  (pOnVWithConf Nothing) bPropV1
                   , mkBench "p-->v" "V2"  (pOnVWithConf Nothing) bPropV2
                   , mkBench "p-->v" "V3"  (pOnVWithConf Nothing) bPropV3
                   , mkBench "p-->v" "V4"  (pOnVWithConf Nothing) bPropV4

                   -- p - p
                   , mkBench "p-->p" "V1"  (bfWith emptyConf) bPropV1
                   , mkBench "p-->p" "V2"  (bfWith emptyConf) bPropV2
                   , mkBench "p-->p" "V3"  (bfWith emptyConf) bPropV3
                   , mkBench "p-->p" "V4"  (bfWith emptyConf) bPropV4

                   -- v - p
                   , mkBench "v-->p" "V1"  (bfWithConf (toAutoConf d0Conf) emptyConf) bProp
                   , mkBench "v-->p" "V2"  (bfWithConf (toAutoConf d2Conf) emptyConf) bProp
                   , mkBench "v-->p" "V3"  (bfWithConf (toAutoConf d3Conf) emptyConf) bProp
                   , mkBench "v-->p" "V4"  (bfWithConf (toAutoConf d4Conf) emptyConf) bProp
                   , mkBench "v-->p" "V4"  (bfWithConf (toAutoConf sumConf) emptyConf) bProp
                   , mkBench "v-->p" "V1*V2"        (bfWith emptyConf) bPropJustV12
                   , mkBench "v-->p" "V1*V2*V3"     (bfWith emptyConf) bPropJustV123
                   , mkBench "v-->p" "V1*V2*V3*V4"  (bfWith emptyConf) bProp
                  ]
    ]

                   --   bench "Auto:VSolve:NoConf"  . nfIO $ satWithConf Nothing emptyConf bProp
                   -- , bench "Auto:PonV:NoConf"  . nfIO $ pOnVWithConf Nothing bProp
                   -- , bench "Auto:BF:NoConf"  . nfIO $ bfWith emptyConf bProp
