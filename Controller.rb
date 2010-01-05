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
		@formulas.delete_at(@formulasTableView.selectedRow)
		@formulasTableView.reloadData
	end
	
	def browse(sender)
		# Create the File Open Dialog class.
		dialog = NSOpenPanel.openPanel
		# Disable the selection of files in the dialog.
		dialog.canChooseFiles = false
		# Enable the selection of directories in the dialog.
		dialog.canChooseDirectories = true
		# Disable the selection of multiple items in the dialog.
		dialog.allowsMultipleSelection = false
	 
		# Display the dialog and process the selected folder
		if dialog.runModalForDirectory("/usr/local/Library/Formula", file:"*.rb") == NSOKButton
		# if we had a allowed for the selection of multiple items
		# we would have want to loop through the selection
			destination_path.stringValue = dialog.filenames.first
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
	
	def size
		return 1
	end
end