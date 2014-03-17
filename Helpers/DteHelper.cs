using EnvDTE;
using EnvDTE100;
using EnvDTE80;
using EnvDTE90;
using Microsoft.VisualStudio.OLE.Interop;
using Microsoft.VisualStudio.Shell;
using System.Diagnostics;

namespace Helpers
{
    public static class DteHelper
    {
		public static ServiceProvider GetServiceProvider(object _dte)
		{
			var dte = (DTE)_dte;

			var serviceProvider = new ServiceProvider((IServiceProvider)dte);

			DebugSessionManager

			//var debugger = (Debugger5)dte.Debugger;
			//var exceptionGroups = debugger.ExceptionGroups;

			//foreach (ExceptionSettings settings in exceptionGroups)
			//{
			//	Debug.WriteLine(settings.Name);
			//}

			return serviceProvider;
		}
    }
}