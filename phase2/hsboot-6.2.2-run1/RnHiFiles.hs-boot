module RnHiFiles where
import HscTypes
import {-# SOURCE #-} Module
import Outputable
import TcRnTypes

loadInterface
	:: Outputable.SDoc
	-> Module.ModuleName
	-> TcRnTypes.WhereFrom
	-> TcRnTypes.TcRn m HscTypes.ModIface
