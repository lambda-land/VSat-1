module Main where

import Web.Spock hiding (Var)
import Web.Spock.Config
import System.Environment (getEnv)
import System.IO.Error (catchIOError)
import Server

-- Keeping unused imports for repl experience, see docs
-- import VProp.Types
-- import VProp.Gen
-- import Data.Aeson (decode)
-- import qualified Data.ByteString.Lazy.Char8 as B (putStrLn)

-- pprint = B.putStrLn

main :: IO ()
main =
  do
  port <- read <$> (getEnv "PORT") `catchIOError` const (return ("8080" :: String))
  spockCfg <- defaultSpockCfg () PCNoDatabase ()
  runSpock port (spock spockCfg app)
