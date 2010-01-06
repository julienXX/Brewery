class Controller
  attr_writer :formulasTableView


	def awakeFromNib
		@formulas = []
		get_brewed_formulas
		@brewed.each {|f| @formulas << f }
    @formulasTableView.dataSource = self
  end
	
	
  def addFormula(sender)
		new_formula = Formula.new
    new_formula.formula = 'Brewery'
    new_formula.version = '0.1'
    @formulas << new_formula
    @formulasTableView.reloadData
  end
	
	
	def removeFormula(sender)
		if @formulasTableView.numberOfSelectedRows != 0
			@formulas.delete_at(@formulasTableView.selectedRow)
			@formulasTableView.reloadData
		end
	end
	
	
	def get_brewed_formulas
    formulas = %x(/usr/local/bin/brew list).split("\n")
		@brewed = Array.new
		
    formulas.each do |f|
			@installed = Formula.new
      f.chomp!
      @version = %x(/usr/local/bin/brew info #{f}).split("\n")
			
			@installed.formula = f
      @installed.version = @version[0].split(" ")[1]
			@brewed << @installed
    end
		
		return @brewed
	end
	
	
	def brew_update(sender)
		message = %x(brew update)
		alert = NSAlert.new
		alert.messageText = message
		alert.alertStyle = NSInformationalAlertStyle
    alert.addButtonWithTitle("OK")
    response = alert.runModal
	end
	
	
	def numberOfRowsInTableView(view)
    @formulas.size
  end

  
	def tableView(view, objectValueForTableColumn:column, row:index)
    formula = @formulas[index]
    case column.identifier
      when 'formula'
        formula.formula
      when 'version'
        formula.version
    end
  end
end




class Formula
  attr_accessor :formula, :version
	
end