class Stock < ActiveRecord::Base
	require 'csv'
	require 'open-uri'
	require 'json'

	validates :stock, 				presence: true,
														uniqueness: {case_sensitive: false}

	validates	:ticker_symbol, presence: true,
														uniqueness: {case_sensitive: false}


	#this function is not perfectly tested. It could break without test failure.
	def Stock.fetch_new_stocks
		Stock.delete_all
		stock_array = {}
		stock_array[:failed] = []
		stock_array[:inserted] = []
		#loop through the 28 pages of stock names from quandl
		x = 1
		x.times do |i|
			# set data_set_docs = to the "docs" array of objects from the quandl json file
			if data_set_docs = Stock.get_quandl_data(i, 0)
				#for each row of the docs array from the json file
				data_set_docs.each do |row|
					#Stock.new_stock returns a Stock hash based on the row from the json file docs array
					stock_hash = Stock.new_stock(row)
					#if the stock_hash 'saved' field is true, then put the stock hash in the saved array, ortherwise the failed array.
					if stock_hash[:saved]
						stock_array[:inserted] << stock_hash
					else
						stock_array[:failed] << stock_hash
					end
				end
			end
		end
		#retun the saved and inserted stock_array arrays.
		return stock_array
	end

	#scrape a single quandl page and return the "docs" array of objects
	def Stock.get_quandl_data(i, count)
		#set url = to the quandl json url.
		url = "http://www.quandl.com/api/v2/datasets.json?source_code=EOD&per_page=300&page=#{i}&auth_token=sVaP2d6ACjxmP-jM_6V-"
		
		#if the scrape is successful, set the data_string = to the json data if the scrape is successful
		if data_string = open(url).read
			#parse out json file into an object
			data_set = JSON.parse(data_string)
			#return the object
			return data_set["docs"]
		else
			#if the scrape faile, increase the count, launch a failure email, and loop back 
			#through the function to attemps again. attempt 10 times maximum.
			count = count + 1
			if count >= 10
				StockMailer.stocks_failed.deliver_now
				return false
			end
			Stock.get_quandl_data(i, count)
		end
	end

	#return a stock hash based on the parsed rows of the json file.
	def Stock.new_stock(row)
		code = row["code"]
		#remove this string from the stock name to get a clean name.
		realname = row["name"].gsub(/ \(#{code}\) Stock Prices, Dividends and Splits/,"")
		#set stock_hash
		stock_hash = { 
			stock: realname,
			exchange: nil,
			active: true,
			ticker_symbol: code,
			date: nil,
			daily_percent_change: nil,
			daily_volume: nil,
			price_to_earnings: nil,
			ytd_percent_change: nil,
			daily_stock_price: nil,
			stock_industry: nil,
			stock_sector: nil
		}
		#if the new stock data is valid, make the new_stock row a new Stock model object to save to the db.
		new_stock = Stock.new(stock_hash)
		saved = new_stock.save
		#the 'saved' variable will contain true or false. To be used to split into 2 arrays later
		stock_hash[:saved] = saved
		return stock_hash
	end

#this function recieves, the current stock array, and updates it with the stock industries too.
	def Stock.return_industry_array(stock_array)
		stock_array_with_industry = []
		#fetch the array of tickers and related industries.
		stock_industry_array = Stock.fetch_industry_array
		#Loop through each line of the stocks to be inserted.
		stock_array.each do |stock|
			#check if the ticker to be inserted is listed in the industries array
			csv_stock_row = stock_industry_array.select {|a| a[:ticker_symbol]==stock[:ticker_symbol]}
			#if there is no match between the current ticker and the industries list, csb_stock_row will be empty.
			#if it is not empty, then update and save the new industry the table.
			unless csv_stock_row.empty?
				#find the stock to update
				stock_to_update = Stock.find_by(ticker_symbol:stock[:ticker_symbol])
				#set the stock_industry attribute of stock to the industry from the industries list.
				stock_to_update.stock_industry = csv_stock_row[0][:stock_industry]
				#save the stock data to the db.
				stock_to_update.save
				#set the stock_industry attribute of the stock hash to the new vale.
				stock[:stock_industry] = csv_stock_row[0][:stock_industry]
			end
			#regardless of what happens with the industries attirubte, save the stock object to a full list of stock objects
			stock_array_with_industry << stock
		end
		#return list of stock objects.
		return stock_array_with_industry	
	end
		

	#return an array with a list of tickers and their corresponding industry
	def Stock.fetch_industry_array
		#url to scrape for getting the stock industries by ticker.
		url = "https://s3.amazonaws.com/quandl-static-content/Ticker+CSV%27s/Stock+Exchanges/stockinfo.csv"
		stock_industry_array = []
		stock_array_with_industry = []
		#open the csv file and loop through each line of the csv file.
		open(url) do |f|
			f.each_line do |line|
				CSV.parse(line) do |row|
					#substitute out the . and /s with _ to align with what comes from the EOD data from Quandl.
					csv_ticker = row[0].gsub('.','_').gsub('/','_').gsub('-','_')
					#add this row of the csv file to the array to return
					stock_industry_array << {ticker_symbol: csv_ticker, stock_industry: row[3]}
				end
			end 
		end
		#return array of stock tickers and industries.
		return stock_industry_array
	end
end
