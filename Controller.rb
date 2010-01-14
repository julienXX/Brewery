require 'mr_task'

class Controller
  attr_writer :brewedTableView, :info_label
	attr_accessor :progress


	def acceptsFirstResponder
    true
  end
	
	
	def awakeFromNib
		@formulas = []
		@info_label.setStringValue("")
		
		get_brewed_formulas
		@brewed.each {|f| @formulas << f }
    @brewedTableView.dataSource = self
  end
	
	
  def addFormula(sender)
		# Open file dialog
		dialog = NSOpenPanel.openPanel
		dialog.canChooseFiles = true
		dialog.canChooseDirectories = false
		dialog.allowsMultipleSelection = false
			 
		if dialog.runModalForDirectory("/usr/local/Library/Formula", file:nil) == NSOKButton
			@selected_file = dialog.filenames.first.split("/").last.gsub!(/.rb/, "")
		end
		
		@progress.startAnimation(nil)
		@info_label.setStringValue("Installing #{@selected_file}...")
		
		%x(/usr/local/bin/brew install #{@selected_file})
		@version = %x(/usr/local/bin/brew info #{@selected_file}).split("\n")[0].split(" ")[1]
		
		@progress.stopAnimation(nil)
		@info_label.setStringValue("")
		
		new_formula = Formula.new
			new_formula.formula = @selected_file
			new_formula.version = @version
    @formulas << new_formula
    @brewedTableView.reloadData
  end
	
	
	def removeFormula(sender)
		if @brewedTableView.numberOfSelectedRows != 0
			alert = NSAlert.new
				alert.messageText = "Are you sure?"
				alert.alertStyle = NSInformationalAlertStyle
				alert.addButtonWithTitle("Confirm")
				alert.addButtonWithTitle("Cancel")
			response = alert.runModal
			
			case response
			when 1000 #first button from the right, response = confirm
				selected = @formulas.at(@brewedTableView.selectedRow).formula
				%x(/usr/local/bin/brew remove #{selected})
				@formulas.delete_at(@brewedTableView.selectedRow)
				@brewedTableView.reloadData
			end
		end
	end
	
	
	def updateFormula(sender)
		if @brewedTableView.numberOfSelectedRows != 0
			@progress.startAnimation(nil)
			selected = @formulas.at(@brewedTableView.selectedRow).formula
			@info_label.setStringValue("Updating #{selected}...")
			%x(/usr/local/bin/brew install #{selected})
			@progress.stopAnimation(nil)
			@info_label.setStringValue("")
		end
		
	end
	
	
	def updateAllFormulas(sender)
		@progress.startAnimation(nil)
		@brewed.each do |b|
			@info_label.setStringValue("Updating #{b.formula}...")
			puts %x(/usr/local/bin/brew install #{b.formula})
			puts @info_label.stringValue()
		end
		@progress.stopAnimation(nil)
		#@info_label.setStringValue("")
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
	end
	

	def brew_update(sender)
		@progress.startAnimation(nil)
		message = %x(brew update)
		alert = NSAlert.new
			alert.messageText = message
			alert.alertStyle = NSInformationalAlertStyle
			alert.addButtonWithTitle("OK")
		@progress.stopAnimation(nil)
    alert.runModal
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