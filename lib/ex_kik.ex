# https://api.kik.com/#/docs/messaging
defmodule ExKik do
  require Logger

  def get_bot_name, do: Application.get_env(:ex_kik, :bot_name)
  def get_api_key,  do: Application.get_env(:ex_kik, :api_key)
  def get_endpoint, do: Application.get_env(:ex_kik, :endpoint, "https://api.kik.com/v1/")

  def set_webhook(url),
    do: post("config", %{webhook: url})
  def set_webhook(url, features) when is_map(features),
    do: post("config", %{webhook: url, features: features})

  # ============
  # = Messages =
  # ============
  defp picture_message(chat_id, username, picture_url, options) do
    %{
      type: "picture",
      pictureUrl: picture_url,
    }
    |> add_recipient(chat_id, username)
    |> add_options(options)
  end

  defp link_message(chat_id, username, url, options) do
    %{
      type: "link",
      url: url
    }
    |> add_recipient(chat_id, username)
    |> add_options(options)
  end

  defp text_message(chat_id, username, text, options) do
    %{
      type: "text",
      body: text,
    }
    |> add_recipient(chat_id, username)
    |> add_options(options)
  end

  defp video_message(chat_id, username, video_url, options) do
    %{
      type: "video",
      videoUrl: video_url,
    }
    |> add_recipient(chat_id, username)
    |> add_options(options)
  end

  # ==================
  # = Send shortcuts =
  # ==================

  def send_picture(chat_id, username, picture_url, options \\ []) do
    message = picture_message(chat_id, username, picture_url, options)
    send_message(message)
  end

  # Options:
  # attribution:
  # keyboards:
  def send_video(chat_id, username, video_url, options \\ []) do
    message = video_message(chat_id, username, video_url, options)
    send_message(message)
  end

  def send_typing(chat_id, username) do
    post("message", %{
      messages: [
        %{
          chatId: chat_id,
          type: "is-typing",
          to: username,
          isTyping: true,
        }
      ]
    })
  end

  def send_link(chat_id, username, url, options \\ []) do
    message = link_message(chat_id, username, url, options)
    send_message(message)
  end

  def send_text(chat_id, username, text, options \\ []) do
    message = text_message(chat_id, username, text, options)
    send_message(message)
  end

  defp check_options(options) when is_list(options),
    do: Map.new(options)
  defp check_options(options) when is_map(options),
    do: options

  defp add_options(message, options) do
    options = check_options(options)
    Map.merge(message, options)
  end

  defp add_recipient(message, chat_id, username) do
    %{
      chatId: chat_id,
      to: username,
    }
    |> Map.merge(message)
  end

  defp send_message(message) do
    post("message", %{"messages" => [message]})
  end

  def post(endpoint, data) do
    headers = %{"Content-Type" => "application/json"}
    url     = get_endpoint() <> endpoint
    options = [hackney: [basic_auth: {get_bot_name(), get_api_key()}]]
    body    = Poison.encode!(data)

    case HTTPoison.post(url, body, headers, options) do
      {:ok, %{status_code: 200}} ->
        nil

      {:ok, %{status_code: 403}} ->
        # Ignore such errors –
        # These happen when we are not allowed to send a message to a conversation,
        # which can happen when we message a bot, or a chat ID which has expired(?)
        nil

      {:ok, response} ->
        Logger.error "Received error from Kik #{inspect body}"
        Logger.error "Request:\n#{inspect data}"
        Logger.error "Response:\n#{response.body}"

      {:error, error} ->
        Logger.error "Error while calling Kik endpoint: #{inspect error}"
    end
  end
end
