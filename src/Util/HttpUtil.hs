{-# LANGUAGE OverloadedStrings, DeriveDataTypeable #-}

module Util.HttpUtil where

import           Control.Monad
import           Snap.Core
import qualified Data.Text.Lazy.Encoding as E
import qualified Data.Text.Lazy as T
import qualified Data.Text.Encoding as ES
import qualified Data.Text as TS

maxBodyLen = 1000000

readBody :: Snap String
readBody = do 
    liftM (T.unpack . E.decodeUtf8) (readRequestBody maxBodyLen)

writeResponse :: String -> Snap()
writeResponse = writeLBS . E.encodeUtf8 . T.pack

getPar :: String -> Snap (Maybe String)
getPar name = do
  p <- getParam $ ES.encodeUtf8 $ TS.pack $ name
  return $ fmap (TS.unpack . ES.decodeUtf8) p

notFound :: Snap ()
notFound = do modifyResponse $ setResponseStatus 404 "Not found"
              writeBS "Not found"
