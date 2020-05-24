{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -w #-}

module Cut.Lib
  ( entryPoint
  , combineDir
  )
where

import           Control.Lens
import           Control.Monad
import           Control.Monad.Catch
import           Control.Monad.IO.Class
import           Control.Monad.IO.Unlift
import           Cut.Analyze
import           Cut.CutVideo
import           Cut.Ffmpeg
import           Cut.Options
import           Cut.SplitVideo
import           Data.Bifunctor
import           Data.Either
import qualified Data.Text                     as Text
import qualified Data.Text.IO                  as Text
import           Data.Text.Lens
import           Options.Applicative
import           Shelly                  hiding ( FilePath )
import           System.IO.Temp
import           Text.Regex.TDFA         hiding ( empty
                                                , extract
                                                )

entryPoint :: (MonadMask m, MonadUnliftIO m) => m ()
entryPoint = catch main
  $ \exec -> liftIO (print ("Uncaught exception: ", exec :: SomeException))

main :: (MonadMask m, MonadUnliftIO m) => m ()
main = do
  options <- liftIO readSettings
  liftIO $ putStr "started with options: "
  liftIO $ print options

  parsed <- detect options
  case options ^. work_dir of
    Nothing ->
      withTempDirectory "/tmp" "streamedit" $ liftIO . runEdit options parsed
    Just x -> liftIO $ runEdit options parsed x

runEdit :: Options -> [Interval Sound] -> FilePath -> IO ()
runEdit options parsed tempDir = do
  extract options tempDir parsed
  shelly $ combineDir options tempDir
  getMusic options tempDir

combineDir :: Options -> FilePath -> Sh ()
combineDir options tempDir = do
  res <- lsT $ fromText $ Text.pack tempDir
  let paths = Text.unlines $ flip (<>) "'" . ("file '" <>) <$> res
  writefile (fromText $ Text.pack $ tempDir <> "/input.txt") paths
  combine tempDir

readSettings :: IO Options
readSettings = customExecParser (prefs showHelpOnError) $ info
  parseRecord
  (fullDesc <> Options.Applicative.header "Cut the crap" <> progDesc
    "Automated video extracting, can cut out silences"
  )

musicFile :: FilePath
musicFile = "music.mp3"

withMusicFile :: FilePath
withMusicFile = "combined.mkv"

getMusic :: Options -> FilePath -> IO ()
getMusic opt' tempDir = do
  res <- case opt' ^. music_track of
    Nothing -> pure $ Text.pack combinedFile
    Just x  -> do
      shelly $ ffmpeg $ args x
      shelly $ combineMusic tempDir
      pure $ Text.pack (tempDir <> "/" <> withMusicFile)
  putStrLn "done get music"
  shelly $ cp (fromText res) (opt' ^. out_file . packed . to fromText)
  pure ()
 where -- https://stackoverflow.com/questions/7333232/how-to-concatenate-two-mp4-files-using-ffmpeg
  combinedFile = tempDir <> "/" <> combineOutput
  args x' =
    [ "-i"
    , opt' ^. in_file . packed
    , "-map"
    , "0:" <> Text.pack (show x')
    , Text.pack (tempDir <> "/" <> musicFile)
    ]

combineMusic :: FilePath -> Sh ()
combineMusic tempDir = void $ ffmpeg args
 where -- https://stackoverflow.com/questions/7333232/how-to-concatenate-two-mp4-files-using-ffmpeg
  args =
    [ "-i"
    , Text.pack $ tempDir <> "/" <> combineOutput
    , "-i"
    , Text.pack $ tempDir <> "/" <> musicFile
    , "-filter_complex"
    , "[0:a][1:a]amerge=inputs=2[a]"
    , "-map"
    , "0:v"
    , "-map"
    , "[a]"
    , "-c:v"
    , "copy"
    , "-c:a"
    , "mp3"
    , "-ac"
    , "2"
    , "-shortest"
    , Text.pack (tempDir <> "/" <> withMusicFile)
    ]
