class ResourcesController < ApplicationController
  def user
    proxy(:get, "/users/#{safe_id}")
  end

  def cart
    proxy(:get, "/carts/#{safe_id}")
  end

  def checkout_session
    proxy(:post, "/checkout-sessions/#{safe_id}", body: request.request_parameters)
  end

  def product
    proxy(:get, "/products/#{safe_id}")
  end

  def order
    proxy(:get, "/orders/#{safe_id}")
  end

  def cancel_order
    proxy(:post, "/orders/#{safe_id}/cancel", body: request.request_parameters)
  end

  def account
    proxy(:get, "/accounts/#{safe_id}")
  end

  def inventory
    proxy(:get, "/inventory/#{safe_id}")
  end

  def recommendations
    proxy(:get, "/recommendations/#{safe_id}", query: request.query_parameters)
  end

  def search
    proxy(:get, "/search", query: request.query_parameters)
  end

  def create_session
    proxy(:post, "/sessions", body: request.request_parameters)
  end

  def preferences
    proxy(:get, "/profiles/#{safe_id}/preferences")
  end

  def health
    render json: {
      ok: true,
      service: "ores-ror.rb",
      request_id: request.request_id,
      thread_id_for_diagnostics_only: Thread.current.object_id
    }
  end

  private

  def safe_id
    value = params.require(:id).to_s
    raise ActionController::BadRequest, "invalid id" unless value.match?(/\A[A-Za-z0-9_-]{1,128}\z/)
    value
  end

  def proxy(method, path, body: nil, query: nil)
    result = HttpDatabase.request(method, path, body: body, query: query || {})
    render json: result.fetch(:body), status: result.fetch(:status)
  end
end
