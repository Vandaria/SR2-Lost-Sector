import buildings;
from buildings import IBuildingHook;
import resources;
import util.formatting;
import systems;
import saving;
from statuses import IStatusHook, Status, StatusInstance;
from resources import integerSum, decimalSum;
import planet_types;
import planet_levels;
import generic_effects;
import hook_globals;
import buildings;
from buildings import IBuildingHook;
import resources;
import util.formatting;
import systems;
import saving;
import influence;
from influence import InfluenceStore;
from statuses import IStatusHook, Status, StatusInstance;
from resources import integerSum, decimalSum;
import orbitals;
from orbitals import IOrbitalEffect;
import attributes;
import hook_globals;
import research;
import empire_effects;
import repeat_hooks;
import planet_types;
import cargo;
import trait_effects;
import traits;
import generic_hooks;
import abilities;
import target_filters;

#section server
import object_creation;
from components.ObjectManager import getDefenseDesign;
from object_stats import ObjectStatType, getObjectStat;
#section all

//if pop above 
tidy final class IfPopulationAbove: IfHook {
	Document doc("Only applies the inner hook if the population is above a certain amount.");
	Argument amount(AT_Decimal, doc="Population above which to apply the inner effect.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasSurfaceComponent)
			return false;
		return obj.population > amount.decimal;
	}
#section all
}

//if pop above 
tidy final class IfLoyaltyBelow: IfHook {
	Document doc("Only applies the inner hook if the loyalty is below a certain amount.");
	Argument amount(AT_Decimal, doc="Population above which to apply the inner effect.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasSurfaceComponent)
			return false;
		return obj.currentLoyalty < amount.decimal;
	}
#section all
}

tidy final class IfHaveStatusCountover5: IfHook {
	Document doc("Only applies the inner hook if the object has a particular status count above.");
	Argument status(AT_Status, doc="Required status for the effect to apply.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		return obj.getStatusStackCountAny(status.integer) > 5;
	}
#section all
};

tidy final class IfHaveStatusCountover10: IfHook {
	Document doc("Only applies the inner hook if the object has a particular status count above.");
	Argument status(AT_Status, doc="Required status for the effect to apply.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		return obj.getStatusStackCountAny(status.integer) > 10;
	}
#section all
};

tidy final class IfHaveStatusCountover15: IfHook {
	Document doc("Only applies the inner hook if the object has a particular status count above.");
	Argument status(AT_Status, doc="Required status for the effect to apply.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		return obj.getStatusStackCountAny(status.integer) > 15;
	}
#section all
};
//Hookes from Rising Stars/Dalo. Thanks https://github.com/DaloLorn/Rising-Stars :)


class HealFromSubsystem : AbilityHook {
	Document doc("Heals the target object (or fleet) at a rate determined by a subsystem value, while draining supplies (if applicable). If the caster does not have the subsystem, uses a default value.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the healing. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the healing rate is 1 HP per unit of HyperdriveSpeed in such a case.");
	Argument cost("Cost per HP", AT_Decimal, "2.0", doc="Amount of supplies drained per HP of repairs. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all repairs are used in modes 1 and 2.");
	Argument powerCost("Power per HP", AT_Decimal, "2.0", doc="Amount of Power drained per HP of regeneration. Does not apply if the caster is not a ship. Defaults to 2.0. Is fully applied even if not all regeneration is used in modes 1 and 2."); // Doesn't work, we don't have Power yet.
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default healing rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");
	Argument mode("Mode", AT_Integer, "2", doc="How the healing behaves. Mode 0 heals only the target object, mode 1 heals each ship in the target fleet by the value, and mode 2 divides the healing evenly across every member of the target fleet. Defaults to mode 2, and uses mode 2 if an invalid mode is passed to the hook.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null || cost.decimal > caster.Supply /* We don't have Power. || powerCost.decimal > caster.Energy */)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip || targ.obj.isOrbital && mode.integer == 0)
			return true;
		if(targ.obj.hasLeaderAI || targ.obj.isOrbital)
			return true;
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

			
		float repair = 0;
		if(mode.integer == 0) {
			if(target.isShip)
				repair = cast<Ship>(target).blueprint.design.totalHP - cast<Ship>(target).blueprint.currentHP;
			else if(target.isOrbital)
				repair = (cast<Orbital>(target).maxHealth + cast<Orbital>(target).maxArmor) - (cast<Orbital>(target).health + cast<Orbital>(target).armor);
		}
		else if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0)
			repair = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		else
			repair = preset.decimal * time;
		float repairCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			repairCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			repairCap = preset.decimal * time; // The 'preset' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(repairCap < repair)
			repair = repairCap;

		if(castedByShip && caster.Supply < (repair * cost.decimal))
			repair = caster.Supply / cost.decimal;
/* We don't have Power yet.
		if(castedByShip && caster.Energy < (repair * powerCost.decimal))
			repair = caster.Energy / powerCost.decimal;
*/
		
		if(castedByShip) {
			caster.consumeSupply(repair * cost.decimal);
// We don't have Power yet.
//			caster.consumeEnergy(repair * powerCost.decimal);
		}
		if(mode.integer == 0){
			if(target.isShip)
				cast<Ship>(target).repairShip(repair);
			else if(target.isOrbital)
				cast<Orbital>(target).repairOrbital(repair);
		}
		else{
			if(mode.integer == 1){
				if(target.hasLeaderAI)
					target.repairFleet(repair, spread=false);
			}
			else{
				if(target.hasLeaderAI)
					target.repairFleet(repair, spread=true);
			}
		}
	}
#section all
};