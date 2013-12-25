class WelcomeController < ApplicationController
	 
	# Сгенеринованный метод для Action == index
	 
	def index


		@src_from_form = params['src']
		@symbols = File.readlines('public/symbols.txt') # читаем из файла
		@symbols=ArrToHash(@symbols) # преобразуем в хеш
		@keywords = File.readlines('public/keywords.txt')
		@keywords=ArrToHash(@keywords)
	
    
		# Промежуточные параметры 

		@tabLex = [] # массив лексем
		@tabNum = [] # массив чисел
		@tabVar = [] # массив идентификаторов
		@tabStr = [] # массив строк
		@tabErr = [] # массив ошибок
		@strnum = 1  # номер строки
		@otkscob = 0 # число скобок
		
		# Выполнение лексического анализа
		Lexer(@src_from_form, @keywords, @symbols)
    
		 
		# Выходные параметры 
		@resultNum = @tabNum
		@resultStr = @tabStr
		@resultVar = @tabVar
		@resultLex = @tabLex
		@resultLexErr = @tabErr

		# синтаксический анализатор
		# Входные параметры 
		@lexId = [] # Идентификатор лексемы (индекс)
		@lexValue = [] # значение лексемы
		@currentLex = 0 # текущий индекс лексемы
 
		# Подготовка к синтаксическому анализу 

		if (@tabLex[0] != nil)
			i=0
			for i in 0...@tabLex.size
				@lexId[i] = @tabLex[i][1] # Идентификатор лексемы
				@lexValue[i] = @tabLex[i][0] # Значение лексемы
			end
		else
			@lexId = [-1] # Идентификатор лексемы
			@lexValue = [-1] # Значение лексемы
		end
	 
		# Промежуточные параметры 
	
		@countVariable = 0 # количество переменных
		@Declare = [] # массив переменных
		@typeExp = 0 # тип выражения
		@item = 0 # Тип переменной
		@TypeS = [] # Контейнер идентификаторов типа String
		@TypeI = [] # Контейнер идентификаторов типа Integer
		@tabRules = [] # дерево выхода
		@tabErrors = [] # таблица ошибок
		@tabOutProgram = "" # выходная программа
		@stateStr # сообщение о результате работы
		@pos=0
		
		# Выполнение синтаксического анализа

		sinAn()
		
		# Выходные параметры 

		@resultRules = @tabRules
		@resultSintaxErr = @tabErrors
		@resultProgram = @tabOutProgram
	end

	
	# Лексический анализатор

	def Lexer(inSource, keyWords, tabSymbols) 
		ind  = 0        # Индекс текущего символа
		csym = ''       # Текущий символ
		lex  = ""       # Лексема
		if inSource.nil?
		  return
		end
		while ind < inSource.size
		  csym = inSource[ind]
		  if isNumber(csym) # если число
			ind = digitHandling(inSource, ind)
		  elsif isApostrophe(csym) # если апостроф
			ind = cstrHandling(inSource, ind)
		  else # иначе проверяем на идентификаторы и символы
		if isLetter(csym)#если буква
		   ind = idntHandling(inSource, ind)
		else # если не буква 
		   ind = simbHandling(inSource, ind)
		end 
		  end
		  ind += 1
		end
		if (@otkscob > 0 || @otkscob < 0)
			row = ["неверное количество скобок", @otkscob]
			@tabErr.push(row)
		end
	end

	
	# Преобразует входной массив, в хэш

	def ArrToHash(inArray)
		hash = {}
		ind  = 0
		while str = inArray.at(ind)
		  if str.index("\r\n") 
			str = str.chop
		  end
		  arr=str.split("|")
		  key=arr[0]
		  arr.delete_at(0)
		  hash[key]=arr
		  ind += 1
		end
		return hash
	end

	
	# Является ли символ цифрой
	
	def isNumber(inSymbol)
		if inSymbol.nil? 
		  return false
		end
		dgtcnt  = inSymbol.scan(/[0-9]/).size
		strsize = inSymbol.size
		result  = false
		if (dgtcnt > 0) & (dgtcnt == strsize) 
			result = true
		end
		result
	end


	# Проверка апострофа

	def isApostrophe(inSymbol)
		if inSymbol.nil? 
		  return false
		end
		cnt     = inSymbol.scan(/[\']/).size
		strsize = inSymbol.size
		result  = false
		if (cnt > 0) & (cnt == strsize) 
			result = true
		end
		result
	end


	# Проверка латинских букв
	
	def isLetter(inSymbol)
		if inSymbol.nil? 
		  return false
		end
		cnt     = inSymbol.scan(/[A-z]/).size
		strsize = inSymbol.size
		result  = false
		if (cnt > 0) & (cnt == strsize) 
			result = true
		end
		result
	end

	
	# Обработка цифры

	def digitHandling(strInput, inIndx)
		lexem   = ""
		type    = 40                    # целая константа
		sym     = strInput[inIndx]
		while isNumber(sym)
		  lexem  += sym
		  inIndx += 1
		  sym    =  strInput[inIndx]
		end
		row = [lexem, type, @strnum] # лексема, тип, номер строки
		@tabLex.push(row)
		if not chckLexInTable(lexem, @tabNum)
		  @tabNum.push(row)
		end
		inIndx-=1
		return inIndx
	end

	
	# Проверка существования лексемы в таблице

	def chckLexInTable(inLexem, arrTab)
		ind  = 0
		while arr = arrTab.at(ind) 
		  if arr[0] == inLexem
			return true
		  end
		  ind += 1
		end
		return false
	end


	# Обработка строки
	
	def cstrHandling(strInput, inIndx)
		lexem   = ""
		type    = 41 
		inIndx  += 1               
		sym     = strInput[inIndx] # строковая константа
		while (sym != '\'' && sym!= '\n' && sym != nil)
		  lexem  += sym
		  inIndx += 1
		  sym    =  strInput[inIndx]
		end
		if (sym == '\n' || sym == nil) # кавычки не закрыты
		  row = ["кавычки не закрыты", @strnum]
		  @tabErr.push(row)
		else # кавычки закрыты
		  row = [lexem, type, @strnum]
		  @tabLex.push(row)
		  if not chckLexInTable(lexem, @tabStr)
			@tabStr.push(row)
		  end
		end
		return inIndx
	end

	 
	# Обработка лексемы и идентификаторы
	 
	def idntHandling(strInput, inIndx)
		lexem   = ""
		type    = 30                    # идентификатор
		sym     = strInput[inIndx]
		while isLetter(sym) || isNumber(sym)
		  lexem  += sym
		  inIndx += 1
		  sym    =  strInput[inIndx]
		end
		islexem = 0 # найдена лексема
		inIndxx = 0
		while (inIndxx < @keywords.size )
		  if (lexem == @keywords.keys[inIndxx])
		   
			type = @keywords.values[inIndxx][0].to_i
			row = [lexem, type, @strnum]
			@tabLex.push(row)
			islexem = 1
		  end
		  inIndxx += 1
		end
		if (islexem == 0) # или идентификатор
		  type = 30
		  row = [lexem, type, @strnum]
		  @tabLex.push(row)
		  if not chckLexInTable(lexem, @tabVar)
			@tabVar.push(row) 
		  end
		  if(lexem[0]=='_') # ошибка в имени идентификатора
			row = [lexem,"неверное имя идентиф.", @strnum]
			@tabErr.push(row)
		  end						
		end
		inIndx-=1
		return inIndx
	end

	 
	#  Обработка символа
	 
	def simbHandling(strInput, inIndx)
		lexem   = ""
		type    = 0                    # символ
		sym     = strInput[inIndx]
		issimbol = 0 # найден символ
		inIndxx = 0
		# проверяем на простые символы
		while (inIndxx < @symbols.size )
		  if (sym == @symbols.keys[inIndxx])
			type = @symbols.values[inIndxx][0].to_i
			row = [sym, type, @strnum]
			@tabLex.push(row)
			issimbol = 1
		  end
		  inIndxx += 1
		end
		# проверяем на сложные символы
		if (issimbol == 0) #простой не найден
		lexem+=sym
		 
			if (sym == '(')
				@otkscob+=1
				type = 25
				row = [sym, type, @strnum]
				@tabLex.push(row)

			elsif (sym == ')')
				@otkscob-=1
				type = 26
				row = [sym, type, @strnum]
				@tabLex.push(row)

			elsif (sym == "\n" )
				@strnum += 1 # увеличиваем номер строки

			elsif (sym == ' ' || sym == "\r" || sym == "\t")
				inIndx += 1
				inIndx -= 1
				
			elsif (sym == ':')
				inIndx += 1
				if (strInput[inIndx] != nil)
					sym = strInput[inIndx]
				end
				lexem += sym
				if (lexem == ":=")
					type = 24
					row = [lexem, type, @strnum]
					@tabLex.push(row)
				else
					type = 27
					row = [":", type, @strnum]
					@tabLex.push(row)
					inIndx -= 1
				end

			elsif (sym == '>')
				inIndx += 1
				if (strInput[inIndx] != nil)
					sym = strInput[inIndx]
				end
				lexem += sym
				if (lexem == ">=")
					type = 21.5
					row = [lexem, type, @strnum]
					@tabLex.push(row)

				else
					type = 21.3
					row = [">", type, @strnum]
					@tabLex.push(row)
					inIndx -= 1
				end

			elsif (sym == '<')
				inIndx += 1
				if (strInput[inIndx] != nil)
					sym = strInput[inIndx]
				end
				lexem += sym
				if (lexem == "<=")
					type = 21.4
					row = [lexem, type, @strnum]
					@tabLex.push(row)
		  
				elsif (lexem == "<>")
					type = 21.1
					row = [lexem, type, @strnum]
					@tabLex.push(row)
		  
				else
					type = 21.2
					row = ["<", type, @strnum]
					@tabLex.push(row)
					inIndx -= 1
				end

			else # запрещенный символ
				row = [sym,"запр. сим.", @strnum]
				@tabLex.push(row)
				@tabErr.push(row)
			end
		end
		return inIndx
	end


   
   
   
  # Синтаксический анализатор
   
	def sinAn()

		if(Program()==0 && @currentLex>=@lexId.size)# если спуск прошел успешно, то вывод сообщения о корректном завершении
			@stateStr="Правильная строка"
		else
			@stateStr="Неправильная строка"
		end
		@currentLex=0
	end

   
  #  проверка нетерминала <Программа>
   

	def Program()
	
		if(@lexId.size==0)	# если текст пуст,то корректное завершение
			@tabRules.push("пусто")
			return 0
		end
		@tabRules.push("<программа> => <объявление переменных> <тело программы>")
		@tabOutProgram<<"#include <stdio.h>"<<"\n"<<"int main(int argc, char *argv[])"<<"\n"<<"{"<<"\n"
		if(Declaration()==0)
		
			if(ProgramBox()==0)
			@tabOutProgram<<"\n"<<"return 0;"<<"\n"<<"}"
				return 0
			else 
				return -1
			end
		else 
			return -1
		end
	end

   
  #  проверка нетерминала <объявление переменных>
   

	def Declaration()

		if(@lexId[@currentLex]==7)# если текущая лексема var
		
			@tabRules.push("<объявление переменных> => var <список переменных>")
			@currentLex+=1# переход к следующей лексеме
			if(VarList()==0)
			@tabOutProgram<<"\n"
				return 0
			else 
				return -1
			end
		else
			@tabErrors.push("Следующая лексема должна быть 'var'")
			return -1
		end
	end
   
  #  проверка нетерминала <список переменных>
   
	def VarList()

		@tabRules.push("<список переменных> => <блок переменных> ; <другой список переменных>")
		if(VarBox()==0)
		
			if(@lexId[@currentLex]==20)# если лексема ;
				@tabOutProgram<<"\n"
				if(@lexId[@currentLex]==1) # если begin
					return 0
				end
				@currentLex+=1 # переход к следующей
				if(spisok()==0)
				
					return 0
				else 
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть ';'")
				return -1
			end
		end
		return -1
	end

   
  #  проверка нетерминала <блок переменных>
   
	def VarBox()

		@tabRules.push("<блок переменных> => <список имен> : <тип>")
		@pos=@tabOutProgram.size
		if(NameList()==0)
			@tabOutProgram<<";"
			if(@lexId[@currentLex]==27)# если лексема :
			
				@currentLex+=1# переход
				if(Type()==0)
					return 0
					@tabOutProgram<<"\n"
				else
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть ':'")
				return -1
			end
		else 
			return -1
		end
	end

   	
  #  проверка нетерминала <другой список переменных>
   
  
	def spisok()

		if(VarList()==0)
		
			@tabRules.push("<другой список переменных> => <список переменных>")
			return 0
		else
			@tabRules.push("<другой список переменных> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <список имен>
   
  
	def NameList()

		if(@lexId[@currentLex]==30) # идентификатор
			@tabOutProgram<<@lexValue[@currentLex]
			@tabRules.push("<список имен> => ид. <другой список имен>")
			if(@Declare.include?(@lexValue[@currentLex]))# если переменная уже была объявлена ранее,то вывод о наличии семантической ошибки
				@tabErrors.push("Семантическая ошибка: Эта переменная была объявлена ​​ранее")
			end
			@Declare.push(@lexValue[@currentLex]) # декларируем переменную
			@currentLex+=1	# переход
			@countVariable+=1       # увеличиваем количество переменных,объявленных в одном блоке
			if(NameSp()==0)
				return 0
			else 
				return -1
			end
		else
			return -1
		end
	end

   	
  #  проверка нетерминала <другой список имен>
   
  
	def NameSp()

		if(@lexId[@currentLex]==29)# если лексема ','
			@tabOutProgram<<", "
			@tabRules.push("<другой список имен> => , <список имен>")
			@currentLex+=1    # переход
			if(NameList()==0)
			
				return 0
			else 
				return -1
			end
		else
			@tabRules.push("<другой список имен> => пусто")# больше нет переменных,которые объявляются в этом блоке
			return 0
		end
	end
	
   
  #  проверка нетерминала <тип>
   
  
	def Type()

		if(@lexId[@currentLex]==3) # если лексема integer
		
			setTypeI(@countVariable)# записываем в контейнер с переменными типа integer объявленные в этом блоке переменные
			@tabRules.push("<Тип> => integer")
			@tabOutProgram.insert(@pos, "int ")
			@countVariable=0# обнуляем количество для подготовки к следующему блоку объявления
			@currentLex+=1
			return 0
			
		elsif(@lexId[@currentLex]==4)# если лексема string
		
			setTypeS(@countVariable)# записываем в контейнер с переменными типа string объявленные в этом блоке переменные
			@tabRules.push("<Тип> => string")
			@tabOutProgram.insert(@pos, "string ")
			@countVariable=0# обнуляем количество для подготовки к следующему блоку объявления
			@currentLex+=1
			return 0
		else
			@tabErrors.push("Неверный тип")
			return -1
		end
	end

   
  #  функция записи в контейнер TypeI идентификаторов переменных с типом integer
  # param n - количество переменных,которые нужно записать
   
  
	def setTypeI( n)
		
		for i in (@Declare.count-1).downto(@Declare.count-n) # берем последние n объявленных переменных и записываем их в контейнер
			if(!@TypeS.include?(@Declare[i]))
				@TypeI.push(@Declare[i])
			else							# если переменная уже объявлена другим типом.то вывод ошибки
				@tabErrors.push("Семантическая ошибка: Эта переменная имеет неправильный тип")
			end
		end
	end
	
   
  #  функция записи в контейнер TypeS идентификаторов переменных с типом string
  # param s - количество переменных,которые нужно записать
   

	def setTypeS( s)

		for  i in (@Declare.count-1).downto(@Declare.count-s) # берем последние s объявленных переменных и записываем их в контейнер
		
			if(!@TypeI.include?(@Declare[i]))
				@TypeS.push(@Declare[i])
			else							# если переменная уже объявлена другим типом.то вывод ошибки
				@tabErrors.push("Семантическая ошибка: Эта переменная имеет неправильный тип")
			end
		end
	end

   
  #  проверка нетерминала <тело программы>
   
  
	def ProgramBox()

		if(@lexId[@currentLex]==1)# если лексема begin
		
			@tabRules.push("<тело программы> => begin <послед. операторов> end .")# добавить в конец строки
			@currentLex+=1# переход
			if(OperatorSequence()==0)
			
				if(@lexId[@currentLex]==2)# если лексема end
				
					@currentLex+=1# переход
					if(@lexId[@currentLex]==28)# если лексема .
					
						@currentLex+=1# переход
						return 0
					else
						@tabErrors.push("Следующая лексема должна быть '.'")
						return -1
					end
				else
					@tabErrors.push("Следующая лексема должна быть 'end'")
					return -1
				end
			else 
				return -1
			end
		else
			@tabErrors.push("Следующая лексема должна быть 'begin'")
			return -1
		end
	end
	
   
  #  проверка нетерминала <послед. операторов>
   
  
	def OperatorSequence()

		@tabRules.push("<послед. операторов> => <оператор> <другая послед. операторов>")
		if(Operator()==0)
		
			if(Rest1()==0)
				return 0
			else 
				return -1
			end
		else 
			return -1
		end
	end
	
   
  #  проверка нетерминала <другая послед. операторов>
   
  
	def Rest1()

		if(@lexId[@currentLex]==20)# если лексема ;
		
			@currentLex+=1# переход
			if(OperatorSequence()==0)
			
				@tabRules.push("<другая послед. операторов> => ; <послед. операторов>")
				return 0
			else 
				@tabRules.push("<другая послед. операторов> => ;")
				return 0
			end
		else  
			@tabRules.push("<другая послед. операторов> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <оператор>
   
  
	def Operator()

		if(@lexId[@currentLex]==30) # если текущая лексема переменная
			@tabOutProgram<<@lexValue[@currentLex]
			type=CheckItem()# определяем тип переменной
			@tabRules.push("<оператор> => ид. := <выражение>")
			@currentLex+=1# переход
			if(@lexId[@currentLex]==24)# если лексема :=
				@tabOutProgram<<"="
				@currentLex+=1# переход
				if(Expression()==0)
					@tabOutProgram<<";"<<"\n"
					if(type!=@typeExp)# если типы операндов в присваивании не равны, то вывод о семантической ошибке
						@tabErrors.push("Семантическая ошибка: несоответствие типов")
					end
					return 0
				else
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть ':='")
				return -1
			end
		
		elsif(@lexId[@currentLex]==8)# если лексема if
			@tabOutProgram<<"if("
			@currentLex+=1# переход
			@tabRules.push("<оператор> => if <условие> then <оператор> <иначе, оператор>")
			if(Condition()==0)
			
				if(@lexId[@currentLex]==9)# если лексема then
					@tabOutProgram<<")"<<"\n"
					@currentLex+=1# переход
					if(Operator()==0)
					
						if(elseOp()==0)
							return 0
						else
							return -1
						end
					else
						return -1
					end
				else
					@tabErrors.push("Следующая лексема должна быть 'then'")
					return -1
				end
			else
				return -1
			end
		
		elsif(@lexId[@currentLex]==11)# если лексема while
			@tabOutProgram<<"while("
			@currentLex+=1# переход
			@tabRules.push("<оператор> => while <условие> do <оператор>")
			if(Condition()==0)
				@tabOutProgram<<") "
				if(@lexId[@currentLex]==12)# если лексема do
				
					@currentLex+=1
					if(Operator()==0)
						@tabOutProgram<<"\n"
						return 0
					else
						return -1
					end
				else
					@tabErrors.push("Следующая лексема должна быть 'do'")
					return -1
				end
			else
				return -1
			end
		
		elsif(@lexId[@currentLex]==13)# если лексема for
			@tabOutProgram<<"for("
			@currentLex+=1# переход
			@tabRules.push("<оператор> => for ид. := <выражение> to <выражение> do <оператор>")
			if(@lexId[@currentLex]==30)# если текущая лексема переменная
				@tabOutProgram<<@lexValue[@currentLex]
				temp=""
				temp<<@lexValue[@currentLex]
				@currentLex+=1# переход
				if(@lexId[@currentLex]==24) # если лексема :=
					@tabOutProgram<<"="
					@currentLex+=1# переход
					if(Expression()==0)
						@tabOutProgram<<";"
						if(@typeExp!=15)# если в цикле используются выражения типа string,то вывод об ошибке
						
							@tabErrors.push("Семантическая ошибка: Выражение в цикле должно быть целого типа")
						end
						if(@lexId[@currentLex]==14)# если to
							@tabOutProgram<<temp<<"<"
							
							@currentLex+=1# переход
							if(Expression()==0)
								 @tabOutProgram<<";"<<temp<<"++"
								if(@typeExp!=15)# если в цикле используются выражения типа string,то вывод об ошибке
									@tabErrors.push("Семантическая ошибка: Выражение в цикле должно быть целого типа")
								end
								if(@lexId[@currentLex]==12)# если лексема do
									@tabOutProgram<<")"<<"\n"
									@currentLex+=1# переход
									if(Operator()==0)
										@tabOutProgram<<"\n"
										return 0
									else
										return -1
									end
								else
									@tabErrors.push("Следующая лексема должна быть 'do'")
									return -1
								end
							else 
								return -1
							end
						else
							@tabErrors.push("Следующая лексема должна быть 'to'")
							return -1
						end
					else
						return -1
					end
				else
					@tabErrors.push("Следующая лексема должна быть ':='")
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть 'ид.'")
				return -1
			end
		
		elsif(@lexId[@currentLex]==6)# если лексема write
			@tabOutProgram<<"printf(\""
			@currentLex+=1# переход
			@tabRules.push("<оператор> => write ( <выражение> )")
			if(@lexId[@currentLex]==25)# если лексема (
			
				@currentLex+=1# переход
				if(Expression()==0)
				
					if(@lexId[@currentLex]==26)# если лексема )
						@tabOutProgram<<"\");\n"
						@currentLex+=1# переход
						return 0
					else
						@tabErrors.push("Следующая лексема должна быть ')'")
						return -1
					end
				else 
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть '('")
				return -1
			end
		
		elsif(@lexId[@currentLex]==5)# если лексема read
			@tabOutProgram<<"scanf"
			@currentLex+=1
			@tabRules.push("<оператор> => read ( ид. )")
			if(@lexId[@currentLex]==25)# если лексема (
				@tabOutProgram<<"("
				@currentLex+=1
				if(@lexId[@currentLex]==30)# если текущая лексема переменная
					item=CheckItem()
					if item == 15
						@tabOutProgram<<"\"%d\",&"
					else 
						@tabOutProgram<<"\"%s\",&"
					end
					@tabOutProgram<<@lexValue[@currentLex]
					@currentLex+=1
					if(@lexId[@currentLex]==26)# если лексема )
						@tabOutProgram<<");\n"
						@currentLex+=1
						return 0
					else
						@tabErrors.push("Следующая лексема должна быть ')'")
						return -1
					end
				else
					@tabErrors.push("Следующая лексема должна быть 'ид.'")
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть '('")
				return -1
			end
		
		elsif(@lexId[@currentLex]==1)# если лексема begin
			@tabOutProgram<<"{\n"
			@currentLex+=1
			@tabRules.push("<оператор> => begin <послед. операторов> end")
			if(OperatorSequence()==0)
			
				if(@lexId[@currentLex]==2)# если лексема end
					@tabOutProgram<<"}\n"
					@currentLex+=1
					return 0
				else
					@tabErrors.push("Следующая лексема должна быть 'end'")
					return -1
				end
			end
		else
			@tabErrors.push("Следующая лексема должна быть 'ид.' или 'if' или 'while' или 'for' или 'write' или 'begin' или 'read'")
			return -1
		end
	end
	
   
  #  проверка нетерминала <иначе, оператор>
   
  
	def elseOp()

		if(@lexId[@currentLex]==10)# если лексема else
			@tabOutProgram<<"else\n"
			@currentLex+=1
			@tabRules.push("<иначе, оператор> => else <оператор>")
			if(Operator()==0)
				return 0
			end
		else
			@tabRules.push("<иначе оператор> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <условие>
   
  
	def Condition()

		if(Comparison()==0)
		
			@tabRules.push("<условие> => <сравнение> <лог. оператор, сравнение>")
			if(logOpCon()==0)
			
				return 0
			else 
				return -1
			end
		else 
			return -1
		end
	end
	
   
  #  проверка нетерминала <лог. оператор, сравнение>
   
  
	def logOpCon()

		if(LogicOperator()==0)
		
			@tabRules.push("<лог. оператор, сравнение> => <лог. оператор> <сравнение>")
			if(Condition()==0)
				return 0
			else
				return -1
			end
		else 
			@tabRules.push("<лог. оператор, сравнение> => ничего")
			return 0
		end
	end

   
  #  проверка нетерминала <сравнение>
   
  
	def Comparison()

		if(Expression()==0)
		
			@tabRules.push("<сравнение> => <выражение> отношение <выражение>")
			type1=@typeExp# считываем тип текущего выражения
			type2=0
			@typeExp=0
			# если присутствует один из знаков сравнения
			if(@lexId[@currentLex]==21 || @lexId[@currentLex]==21.1 ||
			 @lexId[@currentLex]==21.2 || @lexId[@currentLex]==21.3 ||
			 @lexId[@currentLex]==21.4 || @lexId[@currentLex]==21.5)
				@tabOutProgram<<@lexValue[@currentLex]
				@currentLex+=1
				if(Expression()==0)
				
					type2=@typeExp# считываем тип текущего выражения
					@typeExp=0
					if(type1!=type2)# если сравнение производится с между разными типами,то вывод ошибки
						@tabErrors.push("Семантическая ошибка: Сравнение не может быть сделано с различными типами")
					end
					return 0
				else 
					return -1
				end
			else
				@tabErrors.push("Следующая лексема должна быть '=' или '<>' или '<' или '>' или '<=' или '>='")
				return -1
			end
		else 
			return -1
		end
	end
	
   	
  #  проверка нетерминала <лог. оператор>
   
  
	def LogicOperator()

		if(@lexId[@currentLex]==15)# если лексема and
			@tabOutProgram<<" && "
			@currentLex+=1
			@tabRules.push("<лог. оператор> => и")
			return 0

		elsif(@lexId[@currentLex]==16)# если лексема or
			@tabOutProgram<<" || "
			@currentLex+=1
			@tabRules.push("<лог. оператор> => или")
			return 0
		else
			return -1
		end
	end
	
   
  #  функция определения типа переменной
  #  return идентификатор типа: 15, если integer; 16, если string
   

	def CheckItem()

		if(@lexId[@currentLex]==40)# если числ. константа,возврат 15
			return 15
		elsif(@lexId[@currentLex]==41)# если стр. константа,возврат 16
			return 16
		elsif(@lexId[@currentLex]==30)# если это переменная
		
			if(@TypeI.include?(@lexValue[@currentLex]))
			# если идентификатор текущей переменной имеется в TypeI,т.е. она была объявлена как integer
				return 15
			elsif(@TypeS.include?(@lexValue[@currentLex]))
			# если идентификатор текущей переменной имеется в TypeS,т.е. она была объявлена как string
				return 16
			else
				@tabErrors.push("Семантическая ошибка: Эта переменная не была объявлена") 
				# если переменная не найдена в контейнерах,то она не была объявлена
			end
		end
	end

   
  #  проверка нетерминала <выражение>
   

	def Expression()

		@item=CheckItem()# определяем тип текущей лексемы
		if(@item==15)# если integer,то идем по спуску числ. выражения
		
			if(NumExpression()==0)
			
				@typeExp=15# тип выражения записываем как integer
				@tabRules.push("<выражение> => <числ. выражение>")
				return 0
			end
		elsif(@item==16)# если string,то идем по спуску стр. выражения
		
			if(StrExpression()==0)
			
				@typeExp=16# тип выражения записываем как string
				@tabRules.push("<выражение> => <стр. выражение>")
				return 0
			end
		else # иначе ошибка
			@tabErrors.push("Следующая лексема должна быть 'стр. конст.' или 'цел. конст.'")
			return -1
		end
	end
	
   
  #  проверка нетерминала <числ. выражение>
   
  
	def NumExpression()

		if(Term()==0)
		
			@tabRules.push("<числ. выражение> => <терминал> <другое числ. выражение>")
			if(NumRest()==0)
				return 0
			else
				return -1
			end
		else 
			return -1
		end
	end
	
   
  #  проверка нетерминала <другое числ. выражение>
   
  
	def NumRest()

		if(@lexId[@currentLex]==22)# если лексема +
			@tabOutProgram<<"+"
			@currentLex+=1
			@tabRules.push("<другое числ. выражение> => + <числ. выражение>")
			if(NumExpression()==0)
				return 0
			else
				return -1
			end
			
		elsif(@lexId[@currentLex]==22.1)# если лексема -
			@tabOutProgram<<"-"
			@currentLex+=1
			@tabRules.push("<другое числ. выражение> => - <числ. выражение>")
			if(NumExpression()==0)
				return 0
			else
				return -1
			end
		else
			@tabRules.push("<другое числ. выражение> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <терминал>
   
  
	def Term()

		if(Multiplier()==0)
		
			@tabRules.push("<терминал> => <множитель> <другой терминал>")
			if(termRest()==0)
				return 0
			else
				return -1
			end
		else 
			return -1
		end
	end

   
  #  проверка нетерминала <другой терминал>
   
  
	def termRest()

		if(@lexId[@currentLex]==23)# если лексема *
			@tabOutProgram<<"*"
			@currentLex+=1
			@tabRules.push("<другой терминал> => * <числ. выражение>")
			if(NumExpression()==0)
				return 0
			else
				return -1
			end
		
		elsif(@lexId[@currentLex]==23.1)# если лексема /
			@tabOutProgram<<"/"
			@currentLex+=1
			@tabRules.push("<другой терминал> => / <числ. выражение>")
			if(NumExpression()==0)
				return 0
			else
				return -1
			end
		else
			@tabRules.push("<другой терминал> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <множитель>
   
  
	def Multiplier()

		if(@lexId[@currentLex]==30 && CheckItem()==15)# если текущая лексема переменная типа integer
			@tabOutProgram<<@lexValue[@currentLex]
			@typeExp=15# устанавливаем тип выражения
			@currentLex+=1
			@tabRules.push("<множитель> => ид.")
			return 0
		
		elsif(@lexId[@currentLex]==40)# если лексема числ. константа
			@tabOutProgram<<@lexValue[@currentLex]
			@typeExp=15# устанавливаем тип выражения
			@currentLex+=1
			@tabRules.push("<множитель> => цел. конст.")
			return 0
		
		elsif(@lexId[@currentLex]==25)# если лексема (
			@tabOutProgram<<"("
			@currentLex+=1
			@tabRules.push("<множительr> => ( <численное выражение> )")
			if(NumExpression()==0)
			
				if(@lexId[@currentLex]==26)# если лексема )
					@tabOutProgram<<")"
					@currentLex+=1
					return 0
				else
					@tabErrors.push("Следующая лексема должна быть ')'")
					return -1
				end
			else 
				return -1
			end	
		else # если не integer, то вывод ошибки
			@tabErrors.push("Семантическая ошибка: Следующая лексема должна быть целого типа")
			return -1
		end
	end

   
  #  проверка нетерминала <стр. выражение>
   

	def StrExpression()

		if(StrTerm()==0)
		
			@tabRules.push("<стр. выражение> => <стр. терминал> <другое стр. выражение>")
			if(strRest()==0)
				return 0
			else
				return -1
			end	
		else 
			return -1
		end
	end
	
   
  #  проверка нетерминала <другое стр. выражение>
   
  
	def strRest()

		if(@lexId[@currentLex]==22)# если лексема +
			@tabOutProgram<<"+"
			@currentLex+=1
			@tabRules.push("<другое стр. выражение> => + <стр. выражение>")
			if(StrExpression()==0)
				return 0
			else
				return -1
			end
		else
			@tabRules.push("<другое стр. выражение> => ничего")
			return 0
		end
	end
	
   
  #  проверка нетерминала <стр. терминал>
   
  
	def StrTerm()

		if(CheckItem()==16)# если string
		
			@typeExp=16# установка типа выражения
			if(@lexId[@currentLex]==30 )# если текущая лексема переменная
				@tabOutProgram<<@lexValue[@currentLex]
				@currentLex+=1
				@tabRules.push("<стр. терминал> => ид.")
				return 0
			
			elsif(@lexId[@currentLex]==41)# если стр. константа
				@tabOutProgram<<"\""<<@lexValue[@currentLex]<<"\""
				@currentLex+=1
				@tabRules.push("<стр. терминал> => стр. конст.")
				return 0
			end
		else # иначе вывод об ошибке о неправильном типе
			@tabErrors.push(" Семантическая ошибка: Следующая лексема должна быть стр. типа")
			@typeExp=15
			return -1
		end
	end

end
