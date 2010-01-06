class Controller
  attr_writer :brewedTableView
	attr_accessor :progress

	def awakeFromNib
		@formulas = []
		
		get_brewed_formulas
		@brewed.each {|f| @formulas << f }
    @brewedTableView.dataSource = self
  end
	
	
  def addFormula(sender)
		dialog = NSOpenPanel.openPanel
		dialog.canChooseFiles = true
		dialog.canChooseDirectories = false
		dialog.allowsMultipleSelection = false
			 
		if dialog.runModalForDirectory("/usr/local/Library/Formula", file:nil) == NSOKButton
			@selected_file = dialog.filenames.first.split("/").last.gsub!(/.rb/, "")
		end
		
		@progress.startAnimation(nil)
		
		%x(/usr/local/bin/brew install #{@selected_file})
		@version = %x(/usr/local/bin/brew info #{@selected_file}).split("\n")[0].split(" ")[1]
		
		@progress.stopAnimation(nil)
		
		new_formula = Formula.new
    new_formula.formula = @selected_file
    new_formula.version = @version
    @formulas << new_formula
    @brewedTableView.reloadData
  end
	
	
	def removeFormula(sender)
		if @brewedTableView.numberOfSelectedRows != 0
			@formulas.delete_at(@brewedTableView.selectedRow)
			@brewedTableView.reloadData
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
		@progress.startAnimation(nil)
		message = %x(brew update)
		alert = NSAlert.new
		alert.messageText = message
		alert.alertStyle = NSInformationalAlertStyle
    alert.addButtonWithTitle("OK")
		@progress.stopAnimation(nil)
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