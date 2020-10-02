#include "include/resource_constants.as"
import orbitals;
import hooks;
import pickups;
import resources;
import influence;
import attributes;
import anomalies;
import camps;
import research;
import buildings;
from buildings import getBuildingID;
import artifacts;
import orders;
from traits import ITraitEffect;
from influence import InfluenceStore;
from pickups import IPickupHook;
from anomalies import IAnomalyHook;
from abilities import Ability, IAbilityHook;
from research import ITechnologyHook;
from map_effects import parseResourceSpec;
import constructions;
from constructions import IConstructionHook;
import random_events;
import cargo;
import generic_hooks;
import repeat_hooks;
import void gainRandomCard(Empire@ emp) from "card_effects";

#section server
from object_stats import ObjectStatType, getObjectStat;
from objects.Asteroid import createAsteroid;
from objects.Anomaly import createAnomaly;
from empire import Creeps;
from objects.Oddity import createSlipstream;
from objects.Artifact import createArtifact;
from piracy import spawnPirateShip;
from game_start import generateNewSystem, SystemGenerateHook;
import object_creation;
from components.ObjectManager import getDefenseDesign;
from object_stats import ObjectStatType, getObjectStat;
import systems;
import influence_global;
import void makeCreepCamp(const vec3d& pos, const CampType@ type, Region@ region = null) from "map_effects";
import Planet@ spawnPlanetSpec(const vec3d& point, const string& resourceSpec, bool distributeResource = true, double radius = 0.0, bool physics = true) from "map_effects";
import achievements;
from construction.Constructible import Constructible;
from Invasion.InvasionMap import increaseInvasionStrength;
import string getRandomFlagshipName() from "card_effects";
import string getRandomPlanetName() from "card_effects";
from util.design_export import resizeDesign;
#section all

//spawnorbitalinraidus

class SpawnOrbitalRange : EmpireTrigger {
	Document doc("Spawn an orbitalRange.");
	Argument type("Core", AT_OrbitalModule, doc="Type of orbital core to use.");
	Argument creep_owned("Creep Owned", AT_Boolean, "False", doc="Whether the orbital should be owned by the creeps.");
	Argument free("Free", AT_Boolean, "False", doc="Whether to make the orbital free of maintenance.");
	Argument add_status(AT_Status, EMPTY_DEFAULT, doc="Status effect to add to the orbital after it is created.");
	Argument set_home(AT_Boolean, "False", doc="Whether to set the orbital as a home object.");
	Argument offset(AT_Decimal, "0", doc="Offset from the object position to spawn.");


#section server
	void activate(Object@ obj, Empire@ emp) const override {
		auto@ def = getOrbitalModule(arguments[0].integer);
		vec3d pos;
		if(obj !is null) {
			pos = obj.position;
			if(obj.isRegion) {
				vec2d off = random2d(obj.radius * 0.4, obj.radius * 0.9);
				pos.x += off.x;
				pos.z += off.y;
			}
			else if(offset.decimal != 0) {
				vec2d off = random2d(offset.decimal*(randomd(0.5 , 1)));
				pos.x += off.x;
				pos.z += off.y;
			}
		}
		
		auto@ orb = createOrbital(pos, def, arguments[1].boolean ? Creeps : emp);
		if(arguments[2].boolean && !arguments[1].boolean)
			orb.makeFree();
		if(add_status.integer != -1)
			orb.addStatus(add_status.integer);
		if(set_home.boolean)
			@emp.HomeObj = orb;
	}

	void init(Empire& emp, any@ data) const override {}
	void postInit(Empire& emp, any@ data) const override { activate(null, emp); }
#section all
};
tidy final class PeriodicData {
	double timer = 0;
	uint count = 0;
};
tidy final class TriggerPeriodicSystem : EmpireEffect {
	BonusEffect@ hook;

	Document doc("Trigger a bonus effect every set interval.");
	Argument function(AT_Hook, "bonus_effects::BonusEffect");
	Argument interval(AT_SysVar, "60", doc="Interval in seconds between triggers.");
	Argument max_triggers(AT_Integer, "-1", doc="Maximum amount of times to trigger the hook before stopping. -1 indicates no maximum triggers.");
	Argument trigger_immediate(AT_Boolean, "False", doc="Whether to first trigger the effect right away before starting the timer.");
	Argument random_margin(AT_Decimal, "0", doc="Random margin for the interval.");

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(arguments[0].str, "bonus_effects::", required=false));
		if(hook is null) {
			error("TriggerPeriodic(): could not find inner hook: "+escape(arguments[0].str));
			return false;
		}
		return GenericEffect::instantiate();
	}

#section server
	double getTimer() const {
		double timer = interval.decimal;
		double margin = random_margin.decimal;
		if(margin != 0)
			timer *= randomd(1.0 - margin, 1.0 + margin);
		return timer;
	}

	void enable(Object& obj, any@ data) const override {
		PeriodicData@ dat;
		if(!data.retrieve(@dat)) {
			@dat = PeriodicData();
			dat.timer = getTimer();
			data.store(@dat);
		}

		if(trigger_immediate.boolean) {
			if(hook !is null)
				hook.activate(obj, obj.owner);
			dat.count += 1;
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		dat.timer -= tick;
		if(dat.timer <= 0.0) {
			if(max_triggers.integer < 0 || dat.count < uint(max_triggers.integer)) {
				if(hook !is null)
					hook.activate(obj, obj.owner);
				dat.count += 1;
			}
			dat.timer += getTimer();
		}
	}

	void enable(Empire& emp, any@ data) const override {
		PeriodicData@ dat;
		if(!data.retrieve(@dat)) {
			@dat = PeriodicData();
			dat.timer = getTimer();
			data.store(@dat);
		}

		if(trigger_immediate.boolean) {
			if(hook !is null)
				hook.activate(null, emp);
			dat.count += 1;
		}
	}

	void tick(Empire& emp, any@ data, double tick) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		dat.timer -= tick;
		if(dat.timer <= 0.0) {
			if(max_triggers.integer < 0 || dat.count < uint(max_triggers.integer)) {
				if(hook !is null)
					hook.activate(null, emp);
				dat.count += 1;
			}
			dat.timer += getTimer();
		}
	}

	void save(any@ data, SaveFile& file) const override {
		PeriodicData@ dat;
		data.retrieve(@dat);

		file << dat.timer;
		file << dat.count;
	}

	void load(any@ data, SaveFile& file) const override {
		PeriodicData dat;
		data.store(@dat);

		file >> dat.timer;
		if(file >= SV_0096)
			file >> dat.count;
	}
#section all
};