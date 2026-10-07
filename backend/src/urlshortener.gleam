import ewe
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import logging

const server_url = "localhost"

type StoreMessage {
  Insert(String, Subject(Option(String)))
  // Insert, with the long url
  Find(String, Subject(Option(String)))
  // Find by key -> returns LongUrl
  Delete(String)
  // Delete by key
}

type Store =
  Subject(StoreMessage)

type App {
  App(store: Store)
}

pub fn main() {
  logging.configure()
  logging.set_level(logging.Info)

  let assert Ok(store_actor) = start_store()

  let app = App(store: store_actor.data)

  let assert Ok(_) =
    supervisor.new(supervisor.OneForAll)
    |> supervisor.add(
      ewe.new(handler: handle_request(_, app))
      |> ewe.bind(to: "0.0.0.0")
      |> ewe.listening(on: 8080)
      |> ewe.supervised,
    )
    |> supervisor.start

  process.sleep_forever()
}

fn handle_store(
  state: #(Dict(String, String), Int),
  // ShortUrl (key) -> LongUrl, LatestId
  message: StoreMessage,
) -> actor.Next(#(Dict(String, String), Int), StoreMessage) {
  case message {
    Insert(entry, reply) -> {
      let id = state.1 + 1
      let key = encode_to_base_62(id)
      let state = dict.insert(state.0, key, entry)
      actor.send(reply, option.Some(key))
      actor.continue(#(state, id))
    }

    Find(key, reply) -> {
      actor.send(reply, dict.get(state.0, key) |> option.from_result())
      actor.continue(state)
    }
    Delete(key) -> {
      let table = dict.delete(state.0, key)
      actor.continue(#(table, state.1))
    }
  }
}

fn start_store() {
  actor.new(#(dict.new(), 0))
  |> actor.on_message(handle_store)
  |> actor.start
}

fn error_response(msg: String) -> ewe.Body {
  ewe.Text(json.object([#("error", json.string(msg))]) |> json.to_string())
  }

fn handle_request(
  request: request.Request(ewe.Connection),
  app: App,
) -> response.Response(ewe.Body) {
  case ewe.read_body(request, 1024) {
    Ok(req) if req.method == http.Post -> {
      let url_decoder = {
        use url <- decode.field("url", decode.string)

        decode.success(url)
      }

      case
        req.body
        |> bit_array.to_string()
        |> result.unwrap("")
        |> json.parse(url_decoder)
      {
        Ok(url) -> {
          case
            actor.call(app.store, waiting: 100, sending: fn(reply) {
              Insert(url, reply)
            })
          {
            option.Some(key) -> {
              let json = json.object([
                #("key", json.string(key)),
                #("long_url", json.string(url)),
                #("short_url", json.string("http://" <> server_url <> "/" <> key))
              ])
              response.new(201)
              |> response.set_header(
                "content-type",
                "text/plain; charset=utf-8",
              )
              |> response.set_body(ewe.Text(json |> json.to_string()))
            }
            option.None -> {
              response.new(500)
              |> response.set_body(error_response("key not found"))
            }
          }
        }
        Error(_) -> {
            response.new(500)
              |> response.set_body(error_response("missing field 'url' in request"))
          }
      }
    }
    Ok(req) if req.method == http.Get -> {
      let key =
        req.path |> string.to_graphemes() |> list.drop(1) |> string.join("")

      let entry =
        actor.call(app.store, waiting: 100, sending: fn(reply) {
          Find(key, reply)
        })

      case entry {
        option.Some(s) -> {
          response.new(200)
          |> response.set_header("content-type", "text/plain; charset=utf-8")
          |> response.set_body(ewe.Text(json.object([#("location", json.string(s))]) |> json.to_string()))
        }

        option.None -> {
          response.new(404)
          |> response.set_header("content-type", "text/plain; charset=utf-8")
          |> response.set_body(error_response("key not found"))
        }
      }
    }
    Ok(req) if req.method == http.Delete -> {
      let key =
        req.path |> string.to_graphemes() |> list.drop(1) |> string.join("")

        actor.send(app.store, Delete(key))

        response.new(204)
        |> response.set_body(ewe.Text("deleted"))
      }
    _ -> {
      response.new(400)
      |> response.set_body(error_response("bad request"))
    }
  }
}

fn encode_to_base_62(n: Int) -> String {
  encode_to_base_62_internal(
    n |> int.floor_divide(62) |> result.unwrap(0),
    n % 62,
    list.new(),
  )
  |> string.join("")
}

fn encode_to_base_62_internal(
  whole: Int,
  remainder: Int,
  acc: List(String),
) -> List(String) {
  let acc =
    acc |> list.prepend(encode_single_digit(remainder) |> result.unwrap(""))
  case whole {
    0 -> acc
    _ ->
      encode_to_base_62_internal(
        whole |> int.floor_divide(62) |> result.unwrap(0),
        whole % 62,
        acc,
      )
  }
}

fn encode_single_digit(n: Int) -> Result(String, Nil) {
  case n % 62 {
    n if n >= 0 && n < 10 -> Ok(int.to_string(n))
    n if n >= 10 && n < 36 ->
      string.utf_codepoint(n + 87)
      |> result.map(fn(c) { string.from_utf_codepoints([c]) })
    n if n >= 36 && n < 62 ->
      string.utf_codepoint(n + 29)
      |> result.map(fn(c) { string.from_utf_codepoints([c]) })
    _ -> Error(Nil)
  }
}
