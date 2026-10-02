# frozen_string_literal: true

module Products
  module Show
    class EndpointController < OresEndpointController
      def show
        product_id = params.fetch(:id).to_s
        raise OresApp::BadRequest, "invalid product id" unless product_id.match?(/\A[A-Za-z0-9_-]{1,128}\z/)

        result = OresApp::HttpDatabase.request(:get, "/products/#{product_id}", query: request.query_parameters)
        payload = result.fetch(:body).merge("controller_execution" => "products/show#show")
        model = Product.new(payload)
        response.set_header("x-ores-controller-execution", "direct")

        format = request.headers["Accept"].to_s.downcase.include?("text/html") ? :html : :json
        render(
          template: "#{self.class.controller_path}/#{action_name}",
          formats: [format],
          locals: { model: model },
          status: result.fetch(:status)
        )
      end
    end
  end
end
