
#ifndef __IDTABLEINTRY_H__
#define __IDTABLEINTRY_H__
#include "DebugUtilities.h"

class IdTableIntry: public DebugUtilities
{
	public:
		inline IdTableIntry()
		{
			inform((typeName(*this) + string(" inited")).c_str());
		}
		virtual ~IdTableIntry() {};

		friend ostream& operator << (ostream& os, const IdTableIntry& o)
		{
			os << typeName(o) << ":: \n";
			return os;
		}

		//-------------------------

};
#endif // !__IDTABLEINTRY_H__