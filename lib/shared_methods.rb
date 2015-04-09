module SharedMethods

	def likes_count
		self.likes.where(like_type: "like").count
	end

	def dislikes_count
		self.likes.where(like_type: "dislike").count
	end

  def has_replies?
  	count = Stream.where(targetable_id: self.id, targetable_type: self.class.name).count
  	if count > 0
  		return true
  	else 
  		return false
  	end
  end

def add_tags(ticker_symbol=nil)
    words = self.content.split
    
    unless ticker_symbol == nil
      #Append target stock name to beginning of text content
      words.unshift("$#{ticker_symbol}")
    end

    tagged_words = words.collect do |word|
      if word[0] == "$"
        #remove first character
        word.slice!(0)
        #Checks word and word minus last character to remove possible punctuation
        if Stock.exists?(ticker_symbol: word)
          word = "<a href = \"/stocks/#{word}/\"> $#{word} </a>"
        elsif Stock.exists?(ticker_symbol: word.slice(0..sentence.length-2))
          word = "<a href = \"/stocks/#{word.slice(0..sentence.length-2)}/\"> $#{word.slice(0..sentence.length-2)} </a>"
        else
          word.prepend("$")
        end

      elsif word[0] == "@"
        #remove first character
        word.slice!(0)
        #Checks word and word minus last character to remove possible punctuation
        if User.exists?(username: word)
          word = "<a href = \"/users/#{word}/\"> @#{word} </a>"
        elsif User.exists?(username: word.slice(0..sentence.length-2))
          word = "<a href = \"/users/#{word.slice(0..sentence.length-2)}/\"> @#{word.slice(0..sentence.length-2)} </a>"
        else
          word.prepend("@")
        end

      else 
        word = word
      end

     end

     self.create_tag!( content: tagged_words.join(" ") )

     return self.tag.content
  end   
end