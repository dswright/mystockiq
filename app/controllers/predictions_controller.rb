class PredictionsController < ApplicationController

	require 'customdate'
	require 'popularity'
	
	def create
		#Obtain user session information from Session Helper function 'current_user'.
		@user = current_user
		stock = Stock.find(prediction_params[:stock_id])

		#Create the prediction settings.
		prediction_start_time = Time.zone.now.utc_time_int.closest_start_time
		prediction_end_time = (Time.zone.now.utc_time_int + 
													(params[:days].to_i * 24* 3600) + 
													(params[:hours].to_i * 3600) + 
													(params[:minutes].to_i * 60)).closest_start_time
		
		prediction = {stock_id: stock.id, prediction_end_time: prediction_end_time, score: 0, active: true, start_price_verified:false, 
									start_time: prediction_start_time, popularity_score:0 }

		#merge the prediction settings with the params from the prediction form.
		prediction.merge!(prediction_params)
		@prediction = @user.predictions.build(prediction)
		@prediction.start_price = stock.daily_stock_price

		@graph_time = prediction_end_time.utc_time_int.graph_time_int


		#Create the stream inserts for the prediction.
		@streams = []
		stream_params_array = stream_params_process(params[:stream_string])
		stream_params_array.each do |stream_item|
			@streams << @prediction.streams.build(stream_item)
		end

		#Create the proper response to the prediciton input.
		response_msgs = []

		invalid_start = false
		if @prediction.invalid?
			response_msgs << "Prediction invalid. Please refresh page and try again."
			invalid_start = true
		end

		if @prediction.active_prediction_exists?
			response_msgs << "You already have an active prediction on #{stock.ticker_symbol}"
			invalid_start = true
		end

		if @prediction.prediction_end_time <= @prediction.start_time
			response_msgs << "Your prediction starts and ends at the same time. Please increase your prediction end time."
			invalid_start = true
		end

		unless invalid_start
			@prediction.save
			@streams.each {|stream| stream.save}
			stream = Stream.where(streamable_type: 'Prediction', streamable_id: @prediction.id).first
			@stream_hash_array = Stream.stream_maker([stream], 0) #gets inserted to top of stream with ajax.
			response_msgs << "Prediction input!"
		end

		@response = response_maker(response_msgs)

		respond_to do |f|
      f.js { 
        if invalid_start
         render 'shared/_error_messages.js.erb'
        else 
          render "create.js.erb"
        end 
      }
    end
	end

	def show

	@prediction = Prediction.find(params[:id])
	@stock = @prediction.stock

		@current_user = current_user

		#Stock's posts, comments, and predictions to be shown in the view
		streams = Stream.where(target_type: "Prediction", target_id: @stock.id).limit(15)


    #unless streams == nil
    #  streams.each {|stream| stream.streamable.update_popularity_score}
    #end


    #this line makes sorts the stream by popularity score.
    #streams = streams.sort_by {|stream| stream.streamable.popularity_score}
    #streams = sort_by_popularity(streams)
    streams = streams.reverse

    unless streams == nil
      @stream_hash_array = Stream.stream_maker(streams, 0)
    end

  	#If active prediction exists, show active prediction
  	if @prediction.active_prediction_exists?
  		@prediction = Prediction.find_by(user_id: @current_user.id, stock_id: @stock.id, active: true)
  	end


  	@comment_stream_inputs = "Prediction:#{@prediction.id}"

    
    @graph_buttons = ["1d", "5d", "1m", "3m", "6m", "1yr", "5yr"]
    #used by the view to generate the html buttons

    gon.ticker_symbol = @stock.ticker_symbol

    respond_to do |format|
      format.html
      format.json {
        graph = Graph.new(@stock.ticker_symbol, current_user) #something slightly different here.. curernt user is not needed.
        #remember these are the ruby functions... that generate the json api.
        render json: {
        :daily_prices => graph.daily_prices,
        :my_prediction => graph.my_prediction,
        :predictions => graph.predictions, 
        :daily_forward_prices => graph.daily_forward_prices,
        :intraday_prices => graph.intraday_prices,
        :intraday_forward_prices => graph.intraday_forward_prices
        }
      }
    end

	end


	private

	#def comment_params
	def prediction_params
		#Obtains parameters from 'prediction form' in app/views/shared.
		#Permits adjustment of only the 'content' & 'ticker_symbol' columns in the 'predictions' model.
		params.require(:prediction).permit(:prediction_end_price, :prediction_comment, :stock_id)
	end
end
