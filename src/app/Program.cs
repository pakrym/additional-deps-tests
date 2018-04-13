using System;
using System.Reflection;

namespace app
{
    class Program
    {
        static void Main(string[] args)
        {
            var assembly = Assembly.Load("hs");
            var type = assembly.GetType("hs.Program");
            var method = type.GetMethod("Main");
            method.Invoke(null, args);
        }
    }
}
