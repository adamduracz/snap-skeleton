Snap Skeleton
=============

Skeleton for new Haskell/Snap RESTful Web Services. I've removed all unrelated
complexity such as Snaplets, Templating, Application state etc to make
it as simple as possible. However, I've included some facilities
and examples for

- Parsing UTF8 encoded JSON request body into Haskell data values
- Generating a JSON response from Haskell data values
- Extracting values from RESTful paths like /users/jack
- Automated testing

So this is kind of a tutorial, or a skeleton, or a framework.. say what? Let's just
say I've put together some shit I like to use when I write web services in Haskell..
This thing emerged when I found myself copy-pasting a lot of code from one project to another.


What's wrong with `snap init`?
==============================

Well, you can do that too, but you'll get a lot of stuff that you ain't
gonna need for a typical RESTful Web Service. Don't you just hate to
look a ton of generated code that you don't understand?

Don't get me wrong here though: I really dig Snap. It's just `snap
init` I find unsuitable for my current needs.

Snap intro
==========

So, I wanted to see what's the minimal snap application like, and
couldn't find that anywhere on the Net. Luckily I had some spare time
and wrote it myself by removing all the stuff I couldn't grok from the
code generated by `snap init`. And, here it is:

~~~ .haskell
lol :: Snap()
lol = method POST $ do 
    reqBody <- readBody
    liftIO $ putStrLn $ "Received " ++ reqBody
    let reply = "You got lolld"
    writeResponse reply  

main :: IO ()
main = quickHttpServe $ route [ ("/", lol) ] 
~~~ 

The main method starts Snap and routes the root url to a function named
`lol`. This function reads the request body (if it was a POST),
then prints it to stdout and finally replies with the same string. 
The `readBody` and `writeResponse` functions are part of the included `HttpUtil` module,
and take care of the UTF-8 encoding and decoding involved.

I think this is not bad: there's hardly any boilerplate there. You could drop the type
signratures too, if you don't find them useful.

Or, if you get to write a lot of actions that parse the request body as
a string and then produce some other string, you could extract this
boilerplate into a function like

~~~ .haskell
processPost :: (String -> String) -> Snap()
processPost f = do 
    reqBody <- liftM (T.unpack . E.decodeUtf8) getRequestBody
    writeLBS $ E.encodeUtf8 $ T.pack $ f $ reqBody
~~~

JSON
====

Using Text.JSON.Generic, working with JSON data is easy and fun. Like in
my extremely simple example "JsonEcho", you just define your data type
to match the JSON structure and call `encode`:

~~~ .haskell
{-# LANGUAGE DeriveDataTypeable #-}
import           Text.JSON.Generic

data Hello = Hello { message :: String } deriving (Data, Typeable, Show)

jsonMessage = encode $ Hello "Hello!"
~~~

This will generate a JSON string as in

~~~ .JSON
{ "message" : "Hello!" }
~~~

Parsing JSON is similarly easy. Just use the `encode` function.

RESTful Web Services
====================

Suppose you wanted to create a RESTful web service for storing bananas (ok, you can kick me).
You'd want to store new bananas by

~~~
POST /banana {"color": "yellow"}

=> 1
~~~

and get existing bananas by

~~~
GET /banana/1

=> {"color": "yellow"}
~~~

I included this example in `examples/Restful.hs`. It looks like this:

~~~ .haskell
data Banana = Banana { color :: String } deriving (Data, Typeable, Show)

bananas :: Snap()
bananas = newBanana <|> getBanana 

newBanana = method POST $ do 
    banana <- (liftM decodeJSON readBody) :: Snap Banana
    let bananaId = "1"
    writeResponse $ encodeJSON $ bananaId 


getBanana = restfulGet getBanana'    
  where getBanana' "1" = writeResponse $ encodeJSON $ Banana "yellow"
        getBanana' _   = notFound
~~~

The `restfulGet` function is a helper that extracts the `id` parameter from the URL for you. 
The URL mapping is defined in `Main.hs` using the URL pattern `/banana/:id`. 
This tells Snap that the rest of the path should be mapped into the parameter named "id".
The only inconvenient thing is that Snap won't give you access to params as `Strings`, 
but as strict `ByteStrings` instead. I wrote some plumbing code to get that sorted; in `HttpUtil.hs`
there's a function named `getPar` that gives you just that.

Automatic testing
=================

I included automatic tests for the sample code. The `run-tests.sh` script runs 'em. 
It uses `Specs.hs` to find all tests to be run, so you should hook all your tests into the "test suite" by including them in `Specs.hs`.

I use [HSpec] for testing/speccing pure code the [BDD](http://en.wikipedia.org/wiki/Behavior_Driven_Development) way.
In `FunctionalTest.hs` there are also [functional tests](http://en.wikipedia.org/wiki/Functional_testing) for the example web services.
These tests are implemented using [HUnit](http://hunit.sourceforge.net/), because HSpec doesn't currently support testing non-pure code.
I've included some facilities for making web service testing easy, so you can just write

~~~ .haskell
module FunctionalSpec where

import Snap.Http.Server.Config
import Test.HUnit
import qualified Main as Main
import Util.HttpTester

functionalTests = wrapTest withTestServer $ TestList [
  post "Echo string" url "/echo" "lol" $ Matching "l.*l"
  , post "Echo JSON" url "/jsonecho" "{\"message\":\"hola\"}" $ Exactly "{\"message\":\"hola\"}"
  , post "POST restful Banana" url "/banana" "{\"color\":\"yellow\"}" $ Exactly "\"1\""
  , get "GET restful Banana" url "/banana/1" $ Exactly "{\"color\":\"yellow\"}" 
  , get "Unknown Banana not found - 404" url "/banana/2" $ ReturnCode 404
  ]

port = 8001
url= "localhost:" ++ (show port) 

withTestServer = withForkedServer $ Main.serve (setPort port defaultConfig) 
~~~

This will do an HTTP POST to your web service using the path `/echo`, 
writing `lol` into the request body and finally testing that the server will respond with a string 
starting with `l` and ending with `l`. Yep, that's a regex.

It also tests the other example services I included in snap-skeleton, in a self-documenting way (think so?).

This test module uses the utilities defined in HttpTester:

- `wrapTest' wraps any HUnit Test with a given wrapper, so that you can do stuff before and after the actual test
- `withForkedServer` is a wrapper that forks a given action in its own thread and kills the thread after the test
- `post` creates a Test that POSTs given data to given URL and verifies the result using `Matching`, `Exactly` or `ReturnCode`
- `get` creates a similar Test for HTTP GET

This test uses `Main.serve (setPort port defaultConfig)` as the argument for `withForkedServer` to start up the example web services in the port 8001.

Status
======

This stuff is under progress! Here's the backlog:

- Possibly move HttpTester stuff into its own project and publish in Cabal
- Xml examples? Is there any XML serialization library for mapping Haskell data types into XML?
- Convert this into a template like in Giter8 (which fails because it seems to have problems with dollar $igns)
