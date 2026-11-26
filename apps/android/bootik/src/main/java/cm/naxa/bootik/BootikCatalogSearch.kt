package cm.naxa.bootik
import java.text.Normalizer
import java.util.Locale
object BootikCatalogSearch{
 private fun norm(value:String)=Normalizer.normalize(value,Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"").lowercase(Locale.ROOT).trim()
 fun matches(value:String,query:String)=norm(value).contains(norm(query))
}
