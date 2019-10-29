module Stream2YT.Jumpcutter
  ( jump, outName
  ) where

import           Control.Lens
import qualified Data.Text         as T
import           Data.Text.Lens
import           Stream2YT.Options
import           Turtle            hiding (FilePath)

--    ./jumpcutter
--  --input_file /tmp/place-input004.mp4
  --temp_folder /tmp/TEMP47 --frame_margin 2
outName :: T.Text
outName = "jumpout.mp4"

jump :: FilePath -> Options -> Shell ()
jump tmp opt' =
  procs "jumpcutter" ["--input_file"
                 , opt' ^. in_vid . packed
                 , "--temp_folder"
                 , tmp ^. packed <> "/special"
                 , "--frame_margin"
                 , "4"
                 , "--sounded_speed"
                 , "1.0"
                 -- , "--silent_speed"
                 -- "10"
                 , "--output_file"
                 , (tmp ^. packed) <> outName
                 ] $ pure mempty

